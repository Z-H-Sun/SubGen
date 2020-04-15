#encoding: UTF-8
#Used BaiduOCR. Documentation: https://cloud.baidu.com/doc/OCR/s/Ek3h7xypm
#If you use SubOCR.exe on Windows, make sure to use Ruby 1.8.7 syntax

#######################################################
#Define configurations here. Please change accordingly.

QUIET_MODE = false # Whether to hide tips and/or questions during running; however, fatal errors will still be displaced anyway
TOTAL_MOIETIES = 4 # To combine how many subtitle images into one (recommend 2-5)
MOIETY_REGION = 0.95 # Which part the region containing the subtitle is, which will then be clipped out of the original image (0.0 = At the top; for most movies, use values close to 1.0 indicating the subtitle is at the bottom)
API_KEY = [['SOS******************29G', 'ar4**************************rkq'], # API_KEY, followed by SECRET_KEY
           ['nd7******************13V', 'HzE**************************5iC'], # You must replace the placeholders here
           ['BR6******************oFV', '2vb**************************Kt6']] # Add here as many as you can have (If one fails, the next can back up)
OCR_RANGE = 0..-1 # The range of images to run OCR ([0..-1] means ALL)
LANG_TYPE = 'CHN_ENG' # The OCR language type. Can be any of the following: CHN_ENG, ENG, JAP, KOR, FRE, SPA, POR, GER, ITA, RUS
DEFAULT_MODE = ['accurate_basic', 'general_basic'] # OCR modes (change ONLY the sequence if necessary). Try the first one; if unavailable, fallback to the next. 

#EndDefinition. Check again and run!
#######################################################

require 'jpeg'
require 'net/https'

########################LICENSE########################
=begin

This software is based in part on the work of
the Independent JPEG Group and NAKAMURA Usaku

Copyright (C) 1991-2018, Thomas G. Lane, Guido Vollbeding.
All rights reserved.

Copyright (c) 2007,2011 NAKAMURA Usaku usa@garbagecollect.jp
All rights reserved.

=end
#######################################################

unless QUIET_MODE
  STDERR.print "\n* Enter the (relative or absolute, drag-drop supported) path of `VideoSubFinder\' here, or directly press Enter to use the current directory (#{Dir.pwd}): "
  p = STDIN.gets.strip.gsub('"', '').gsub("'", '').gsub('\ ', '')
  begin
    Dir.chdir(p)
  rescue
    STDERR.puts '=>Will use the current directory.'
  end
end
begin
  files = Dir.entries('RGBImages').sort
  files.delete_if {|i| File.extname(i) != '.jpeg'}
  files = files[OCR_RANGE]
rescue
  files = []
end
if files.empty?
  STDERR.print '=>NO `.JPEG\' IMAGE in this folder or OCR_RANGE is ill-defined. Please Enter to exit'
  STDIN.gets; exit
end
fileLists = [] # list of groups of every OCR_RANGE files
while files.size > TOTAL_MOIETIES
  fileLists << files.shift(TOTAL_MOIETIES)
end
fileLists << files # the final group

@http = Net::HTTP.new('aip.baidubce.com', 443)
@http.use_ssl = true
@http.verify_mode = 0
STDERR.puts "\n* Checking validity of API_KEYs..." unless QUIET_MODE
@token = []
@tokenIndex = 0 # index of the default API_KEY to use
@groupIndex = 0
req = Net::HTTP::Post.new('/oauth/2.0/token', initheader={'Content-Type' => 'application/json; charset=UTF-8'})
for i in API_KEY
  req.set_form_data({'grant_type' => 'client_credentials', 'client_id' => i[0], 'client_secret' => i[1]})
  begin
    res = @http.request(req)
    @token << res.body.scan(/"access_token".*?"(.*?)"/)[0][0]
  rescue
    STDERR.puts '=>Please check: Network failed, or API_KEY [' + i[0] + '] invalid'
  end
  if @token.empty?
    STDERR.print '=>NO API_KEY VALID. Please press Enter to exit, and make changes to configurations in `SubOCR.rb\''
    STDIN.gets; exit
  end
end

def spliceJPEG(fileList)
  data = ''
  for i in 0...TOTAL_MOIETIES
    begin
      f = open('RGBImages/'+fileList[i], 'rb')
      if TOTAL_MOIETIES == 1
        dataB64 = [f.read].pack('m') # Base64 encode
        f.close
        return dataB64
      end
    rescue
      next
    end
    img = JPEG.read(f)
    d = img.raw_data
    pixelSize = img.gray? ? 1 : 3 # for colored image, each pixel occupies 3 byte: R, G, and B
    data += d[((img.height-img.height/TOTAL_MOIETIES)*MOIETY_REGION).to_i*pixelSize*img.width, img.height/TOTAL_MOIETIES*pixelSize*img.width]
    f.close
  end

  remainder = "\0" * (d.size-data.size) # fill the rest pixels with black color
  img.raw_data = data + remainder
  ff = open('RGBImages/splice.jpg', 'w+b')
  JPEG.write(img, ff)

  ff.seek(0)
  dataB64 = [ff.read].pack('m') # Base64 encode
  ff.close
  return dataB64
end

def OCR(dataB64, fileList, mode=0)
  req = Net::HTTP::Post.new('/rest/2.0/ocr/v1/'+DEFAULT_MODE[mode], initheader={'Content-Type' => 'application/x-www-form-urlencoded'})
  req.set_form_data({"image" => dataB64, "access_token" => @token[@tokenIndex], 'paragraph' => 'true', 'language_type' => LANG_TYPE})
  begin
    res = @http.request(req)
    raise unless res.is_a?(Net::HTTPOK)
  rescue # network problem
    STDERR.puts "=>Network failure"
    STDERR.flush
    return
  end

  begin # OCR returns error
    errCode = res.body.scan(/"error_code".*?(\d+)/)[0][0].to_i
    errMsg = res.body.scan(/"error_msg".*?"(.*?)"/)[0][0]
    if errCode < 120 and @tokenIndex < @token.size-1 # if so, mostly due to API_KEY unavailability, resolve by changing API_KEY
      STDERR.puts "=>#{errMsg}\n=>Switching to the next API_KEY..." unless QUIET_MODE
      STDERR.flush
      @tokenIndex += 1
      return OCR(dataB64, fileList, mode)
    else # failure in ACCURATE mode, or no more API_KEY available
      if mode == 0 # try to resolve by changing mode to GENERAL
        STDERR.puts "=>#{errMsg}\n=>Falling back on GENERAL mode..." unless QUIET_MODE
        STDERR.flush
        return OCR(dataB64, fileList, 1)
      else
        STDERR.puts "=>FATAL: #{errMsg}"
        STDERR.flush
        return
      end
    end
  rescue # no error so far
    words = res.body.scan(/"words".*?"(.*?)"/).flatten
    paragraphs = res.body.scan(/"words_result_idx".*?(\[.*?\])/).flatten
    if words.empty? or paragraphs.empty?
      STDERR.puts "=>FATAL: No result returned"
      STDERR.flush
    end
    results = []
    for i in paragraphs
      result = []
      i.scan(/\d+/).each{|j|result << words[j.to_i]}
      results << result.join("\n")
    end
    if paragraphs.size < fileList.size
      STDERR.puts '=>WARNING: Combined paragraph data parsing failure (Paragraph size < total moieties). You may need to transfer some text in one subtitle to another'
      STDERR.flush
      results += ['']*(fileList.size-paragraphs.size) # complement the array
      results.each_with_index {|i, x| results[x] = '!@!' + i} # each starts with flag `!@!` to indicate failure in parsing
    elsif paragraphs.size > fileList.size
      STDERR.puts '=>WARNING: Combined paragraph data parsing failure (Paragraph size > total moieties). You may need to transfer some text in one subtitle to another'
      STDERR.flush
      results[fileList.size-1] += "\n" + results[fileList.size..-1].join("\n") # add the remaining results to the last item
      results.each_with_index {|i, x| results[x] = '!@!' + i} # each starts with flag `!@!` to indicate failure in parsing
    end
    return results[0, fileList.size]
  end
end

def saveResults(results, fileList)
  Dir.mkdir('TXTResults') unless File.directory?('TXTResults')
  STDERR.puts
  fileList.each_with_index do |i, x|
    puts '@ ' + i
    puts results[x] unless results.nil?
    puts
    f = open('TXTResults/'+i[0, i.size-5]+'_0.txt', 'wb')
    f.write(results[x]); f.close
  end
  @groupIndex += 1
end

unless QUIET_MODE
  STDERR.puts "\n* Please also check the following:\n=>You have [#{@token.size}] valid API_KEYs (but they may be unavailable due to limit of requests per day)\n=>You defined the range of images to be OCR'ed as [#{OCR_RANGE.inspect}] (total = #{fileLists.flatten.size})"
  if TOTAL_MOIETIES > 1
    STDERR.puts "=>You decided to splice together [#{TOTAL_MOIETIES}] images into one to reduce API requests needed\n=>For each clipped image, you chose the part that is [#{MOIETY_REGION}]*[Height(originalImage)-Height(clippedImage)] away from the top"
  else
    STDERR.puts "=>You decided NOT to splice images, which is deprecated due to limit on API requests per day"
  end
  STDERR.print "\n* Press Enter to confirm"
  STDERR.print ", and you will see a sample of the joint picture based on your settings" if TOTAL_MOIETIES > 1
  STDIN.gets
end

unless QUIET_MODE or TOTAL_MOIETIES == 1# preview the first spliced picture
  fGroup = fileLists.shift # the first group
  dataB64 = spliceJPEG(fGroup)
  openCmd = ''
  case RUBY_PLATFORM # define the command to open a file according to os
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/; openCmd= 'start' # windows
    when /darwin|mac os/; openCmd = 'open' # mac os
    when /linux/; openCmd = 'xdg-open' # linux
    else; STDERR.puts '=>Unknown OS. Please open the image `RGBImages/splice.jpg\' manually to check'
  end
  `#{openCmd} RGBImages/splice.jpg` unless openCmd.empty?

  STDERR.print '* Press Enter to commence OCR; or if not satisfied, make changes to the settings in `SubOCR.rb\''
  STDIN.gets
  
  STDERR.puts "\n"+'-'*60; STDERR.puts '* OCR\'ing group #1...'
  saveResults(OCR(dataB64, fGroup), fGroup)
end

t0 = Time.now
fileLists.each_with_index do |i, x|
  STDERR.puts '-'*60
  STDERR.puts "* OCR'ing group ##{@groupIndex+1}... (%.1f%%, elapsed time = %.1f seconds)" % [x*100.0/fileLists.size, Time.now-t0]
  saveResults(OCR(spliceJPEG(i), i), i)
end
