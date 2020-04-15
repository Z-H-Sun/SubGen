Public Class Form2

    Dim Lf, Tp, Wd, Ht, currentPage, totalEnabled As Integer, txtChanged As Boolean
    ' Of the subtitle region (of the original): left, top, width, height;
    ' Current page number; number of entries of the current page (usually 20, sometimes < 20);
    ' Whether there is any change in texts in the current page
    Dim TxtResults(Form1.RGBImgs.Count - 1) As String
    ' Filenames of .txt files in the TXTResults folder, including those non-existing ones (to be created)
    Dim SavedPages As New List(Of Integer) ' Which pages have been saved
    Dim Labels As IEnumerable(Of Label), PictureBoxes As IEnumerable(Of PictureBox), TextBoxes As IEnumerable(Of TextBox) ' The group of 20 controls (labels, pictureboxes, and textboxes), in the reverse sequence (e.g. Label20, Label19, ..., Label1)!

    Private Sub Form2_KeyDown(ByVal sender As Object, ByVal e As System.Windows.Forms.KeyEventArgs) Handles Me.KeyDown
        On Error Resume Next
        Select Case e.KeyCode
            Case Keys.PageDown ' next page
                If txtChanged Then
                    If MsgBox("Detected text change. Proceed to the next page without saving?", MsgBoxStyle.Question Or MsgBoxStyle.YesNo) = MsgBoxResult.No Then Exit Sub
                End If
NextP:
                currentPage += 1
                ' if > max then goto the first page
                If currentPage * 20 >= TxtResults.Count Then currentPage = 0
                LoadPage(currentPage)
            Case Keys.PageUp
                If txtChanged Then
                    If MsgBox("Detected text change. Proceed to the next page without saving?", MsgBoxStyle.Question Or MsgBoxStyle.YesNo) = MsgBoxResult.No Then Exit Sub
                End If
                currentPage -= 1
                ' if < min then goto the last page
                If currentPage < 0 Then currentPage = Math.Ceiling((TxtResults.Count / 20)) - 1
                LoadPage(currentPage)
            Case Keys.Down, Keys.Up
                Dim curInd, selStart As Integer
                ' find the current textbox
                For i = 0 To 19
                    If TextBoxes(i).Focused Then curInd = 19 - i ' inverse sequence
                Next
                ' the cursor position
                selStart = TextBoxes(19 - curInd).SelectionStart
                If e.Shift Then ' select to begin/end
                    e.SuppressKeyPress = True ' nullify
                    If e.KeyCode = Keys.Down Then
                        TextBoxes(19 - curInd).SelectionLength = TextBoxes(19 - curInd).Text.Length - selStart
                    Else
                        TextBoxes(19 - curInd).Select(0, selStart)
                    End If
                    Exit Sub
                End If
                If e.Control Then ' move to previous/next
                    e.SuppressKeyPress = True
                    If (e.KeyCode = Keys.Up AndAlso curInd = 0) Or (e.KeyCode = Keys.Down AndAlso curInd = totalEnabled - 1) Then Media.SystemSounds.Exclamation.Play() : Exit Sub ' invalid
                    Dim text As String, oriLen As Integer
                    text = TextBoxes(19 - curInd).SelectedText
                    TextBoxes(19 - curInd).SelectedText = ""
                    If e.KeyCode = Keys.Down Then curInd += 1 Else curInd -= 1
                    With TextBoxes(19 - curInd)
                        oriLen = .Text.Length
                        .AppendText(text)
                        .Focus()
                        .Select(oriLen, text.Length)
                    End With
                    Exit Sub
                End If
                ' navigate to the next textbox
                If e.KeyCode = Keys.Down Then curInd += 1 Else curInd -= 1
                ' If > max then goto the first; if < min then goto the last
                curInd = (curInd + totalEnabled) Mod totalEnabled

                TextBoxes(19 - curInd).Focus()
                TextBoxes(19 - curInd).Select(selStart, 0)
            Case Keys.Enter
                For i = 0 To totalEnabled - 1
                    IO.File.WriteAllText(TxtResults(20 * currentPage + i), TextBoxes(19 - i).Text.Replace("|", Environment.NewLine), System.Text.Encoding.UTF8)
                    'TextBoxes(19 - i).BackColor = SystemColors.Window
                    'TextBoxes(19 - i).ForeColor = SystemColors.WindowText
                Next
                txtChanged = False
                'MsgBox("Completed saving", MsgBoxStyle.Information)
                SavedPages.Add(currentPage)
                'Me.Text = "Revision *"

                GoTo NextP ' navigate to the next page
            Case Keys.Escape
                Me.Close()
        End Select
    End Sub

    Private Sub Form2_Resize(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Resize
        On Error Resume Next
        Dim doublesize As Integer ' twice the fontsize
        doublesize = 21 * Me.Height / 570 ' change the fontsize accordingly
        If doublesize = Me.Font.Size * 2 Then Exit Sub

        Dim newf As New Font(Me.Font.FontFamily, CSng(doublesize / 2), FontStyle.Regular)
        Me.Font = newf
    End Sub

    Private Sub Form2_FormClosed(ByVal sender As Object, ByVal e As System.Windows.Forms.FormClosedEventArgs) Handles Me.FormClosed
        Dialog1.Show()
    End Sub

    Private Sub Form2_Load(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles MyBase.Load
        ' the subtitle region
        Lf = Int(Form1.Label1.Text)
        Tp = Int(Form1.Label2.Text)
        Wd = Int(Form1.Label3.Text) - Lf
        Ht = Int(Form1.Label4.Text) - Tp
        ' existing TXTResults files
        Dim TxtResultsOriginal As String() = IO.Directory.GetFiles(Form1.Folder & "\TXTResults", "*.txt")

        Dim RGBImg, Timing As String, ind As Integer, failed As New List(Of String)
        ' map each existing TXTResult file with RGBImage file
        For Each i In TxtResultsOriginal
            Timing = IO.Path.GetFileName(i.Substring(0, i.LastIndexOf("_")))
            ind = Array.IndexOf(Form1.RGBImgs, Form1.Folder & "\RGBImages\" & Timing & ".jpeg")
            If ind < 0 Then
                failed.Add(IO.Path.GetFileName(i))
            Else
                TxtResults(ind) = i
            End If
        Next
        If failed.Count > 0 Then MsgBox("Please Check: No corresponding RGBImgs found for file(s), which will be thus ignored: " & vbCrLf & String.Join(vbCrLf, failed.ToArray), MsgBoxStyle.Exclamation)

        ' if no TXTResult file corresponds to a certain RGBImg file, then create one
        For i = 0 To Form1.RGBImgs.Count - 1
            If TxtResults(i) <> "" Then Continue For
            RGBImg = Form1.RGBImgs(i)
            Timing = IO.Path.GetFileName(RGBImg.Substring(0, RGBImg.Length - 5))
            'Try
            'TxtResults.Add(TxtResultsOriginal.First(Function(x As String) IO.Path.GetFileName(x).Substring(0, Timing.Length) = Timing))
            'Catch ex As Exception
            'TxtResults.Add(Form1.Folder & "\TXTResults\" & Timing & "_1.txt")
            'End Try
            TxtResults(i) = Form1.Folder & "\TXTResults\" & Timing & "_0.txt"
        Next
        Labels = TableLayoutPanel1.Controls.OfType(Of Label)()
        PictureBoxes = TableLayoutPanel1.Controls.OfType(Of PictureBox)()
        TextBoxes = TableLayoutPanel1.Controls.OfType(Of TextBox)()
        LoadPage(0)
    End Sub

    Private Sub LoadPage(ByVal Index As Integer)
        ' except the last page, totalEnabled=20
        totalEnabled = Math.Min(TxtResults.Count - Index * 20, 20)
        For i = 0 To 19
            If i < totalEnabled Then
                LoadPic(20 * Index + i)
                Labels(19 - i).Text = 20 * Index + i + 1 ' inverse sequence
            Else ' no images or texts beyond the totalEnabled number
                Labels(19 - i).Text = ""
                TextBoxes(19 - i).Text = ""
                TextBoxes(19 - i).Enabled = False
                ToolTip1.SetToolTip(PictureBoxes(19 - i), "")
                ToolTip1.SetToolTip(Labels(19 - i), "")
                PictureBoxes(19 - i).Image = Nothing
            End If
        Next
        txtChanged = False
        If SavedPages.Contains(Index) Then Me.Text = "Revision *" Else Me.Text = "Revision"
    End Sub

    Private Sub LoadPic(ByVal Index As Integer)
        Dim txt As String
        Dim Timing As String = IO.Path.GetFileName(Form1.RGBImgs(Index).Substring(0, Form1.RGBImgs(Index).Length - 5))
        Try
            ' Note the encoding here: UTF-8!
            txt = IO.File.ReadAllText(TxtResults(Index), System.Text.Encoding.UTF8).Replace(Environment.NewLine, "|").Replace(vbLf, "|")
            ToolTip1.SetToolTip(PictureBoxes(19 - (Index Mod 20)), TxtResults(Index))
        Catch ex As Exception
            txt = ""
            ToolTip1.SetToolTip(PictureBoxes(19 - (Index Mod 20)), "(New file)")
        End Try
        ' Replace linebreaks into "|" to adapt to a non-multiline textbox
        With TextBoxes(19 - (Index Mod 20))
            .Enabled = True
            .Text = txt
            ' change back to default
            .BackColor = SystemColors.Window
            .ForeColor = SystemColors.WindowText

            If txt.Length >= 3 Then
                If txt.Substring(0, 3) = "!@!" Then
                    .Text = txt.Substring(3)
                    .BackColor = Color.LavenderBlush
                    .ForeColor = Color.Firebrick
                End If
            End If
        End With

        ' Timing
        ToolTip1.SetToolTip(Labels(19 - (Index Mod 20)), Timing.Replace("__", " --> ").Replace("_", ":"))
        ' Crop the original images into subtitle regions
        Dim OriginalImage As Image = Image.FromFile(Form1.RGBImgs(Index))
        Dim CropImage As New Bitmap(Wd, Ht)
        Using grp = Graphics.FromImage(CropImage)
            grp.DrawImage(OriginalImage, New Rectangle(0, 0, Wd, Ht), New Rectangle(Lf, Tp, Wd, Ht), GraphicsUnit.Pixel)
            OriginalImage.Dispose()
            PictureBoxes(19 - (Index Mod 20)).Image = Image.FromHbitmap(CropImage.GetHbitmap)
            CropImage.Dispose()
        End Using
    End Sub

    Private Sub TextBox_TextChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles TextBox1.TextChanged, TextBox2.TextChanged, TextBox3.TextChanged, TextBox4.TextChanged, TextBox5.TextChanged, TextBox6.TextChanged, TextBox7.TextChanged, TextBox8.TextChanged, TextBox9.TextChanged, TextBox10.TextChanged, TextBox11.TextChanged, TextBox12.TextChanged, TextBox13.TextChanged, TextBox14.TextChanged, TextBox15.TextChanged, TextBox16.TextChanged, TextBox17.TextChanged, TextBox18.TextChanged, TextBox19.TextChanged, TextBox20.TextChanged
        ' highlight text changes
        txtChanged = True
        sender.BackColor = SystemColors.Info
        sender.ForeColor = SystemColors.Highlight
    End Sub
End Class