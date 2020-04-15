`chcp 65001 2>nul`
system('title SubOCR v2.02 by Zack')
f = __FILE__
f = ExerbRuntime.filepath if $Exerb
STDERR.print "\nShow OCR results in the terminal window rather than record in logfile? Note: The results will be saved as separate files in the TXTResults folder anyway. [Y/N] "
if STDIN.gets.strip.downcase == "n" then
  STDERR.puts "\n* NOTE: STDOUT is redirected to `#{File.expand_path("SubOCR.output.log")}'" 
  o = open('SubOCR.output.log', 'wb')
  $stdout = o
end
begin
  load File.join(File.dirname(f), 'SubOCR.rb')
rescue Exception
  exit if $!.is_a?(SystemExit)
  STDERR.print "\n* An unexpected error has occurred: [#{$!.class}] "
  STDERR.puts $!.message
  STDERR.print "=>Traceback:\n=>"
  STDERR.puts $@.join("\n=>")
end
STDERR.print "\n* End of operation. Press any key to exit"
`pause`
