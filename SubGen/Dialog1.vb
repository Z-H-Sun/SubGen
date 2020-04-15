Imports System.Text.RegularExpressions

Public Class Dialog1

    Private Sub Dialog1_FormClosing(ByVal sender As Object, ByVal e As System.Windows.Forms.FormClosingEventArgs) Handles Me.FormClosing
        If SaveFileDialog1.ShowDialog(Me) <> Windows.Forms.DialogResult.Cancel Then
            IO.File.WriteAllText(SaveFileDialog1.FileName, TextBox1.Text, System.Text.Encoding.UTF8)
            Form1.Enabled = True
        Else
            If MsgBox("Cancel without saving?", MsgBoxStyle.Question Or MsgBoxStyle.YesNo) = MsgBoxResult.No Then e.Cancel = True Else Form1.Enabled = True
        End If
    End Sub

    Private Sub Dialog1_Shown(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles MyBase.Shown
        TextBox1.ReadOnly = True
        Me.Text = "Please wait..."
        TextBox1.Text = "[Script Info]" & vbCrLf & "Title: SubGen v2" & vbCrLf & "ScriptType: v4.00+" & vbCrLf & vbCrLf & "[V4+ Styles]" & vbCrLf & "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding" & vbCrLf & "Style: Default,SimHei,20,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,20,20,20,0" & vbCrLf & vbCrLf & "[Events]" & vbCrLf & "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text" & vbCrLf
        ' Header
        My.Application.DoEvents()
        ' Header size
        Dim header As Integer = TextBox1.Text.Length
        Dim failed As New List(Of String), result As New System.Text.StringBuilder
        For Each i In IO.Directory.GetFiles(Form1.Folder & "\TXTResults", "*.txt")
            Dim txt As String = IO.File.ReadAllText(i, System.Text.Encoding.UTF8)
            If txt.Trim = "" Then Continue For
            ' replace linebreaks with "\N" per ass format
            txt = txt.Replace(vbCrLf, "\N").Replace(vbLf, "\N")
            ' extract timing data
            Dim matchData As Match = Regex.Match(IO.Path.GetFileName(i), "(\d+)_(\d+)_(\d+)_(\d{2}).*__(\d+)_(\d+)_(\d+)_(\d{2}).*_")
            Try
                Dim matchArray As String() = matchData.Groups.Cast(Of Group)().Select(Function(m) m.Value).ToArray
                result.Append(String.Format("Dialogue: 0,{1}:{2}:{3}.{4},{5}:{6}:{7}.{8},Default,,0,0,0,,", matchArray))
                result.AppendLine(txt)
            Catch ex As Exception
                failed.Add(IO.Path.GetFileName(i))
            End Try
        Next
        TextBox1.AppendText(result.ToString)
        If failed.Count > 0 Then MsgBox("Please Check: No timing info can be extracted in file(s): " & vbCrLf & String.Join(vbCrLf, failed.ToArray), MsgBoxStyle.Exclamation)
        TextBox1.ReadOnly = False
        TextBox1.Select(header, 0)
        TextBox1.ScrollToCaret()
        Me.Text = "Review ASS Results Here (Ctrl+Enter to Exit):"
    End Sub

    Private Sub TextBox1_KeyDown(ByVal sender As Object, ByVal e As System.Windows.Forms.KeyEventArgs) Handles TextBox1.KeyDown
        ' suppress the "press event" of enter key
        If e.KeyCode = Keys.Enter AndAlso (e.Shift Or e.Control) Then e.SuppressKeyPress = True
    End Sub

    Private Sub EnterKeyUp(ByVal sender As Object, ByVal e As System.Windows.Forms.KeyEventArgs) Handles Me.KeyUp
        If e.KeyCode = Keys.Enter AndAlso (e.Shift Or e.Control) Then Me.Close()
    End Sub
End Class
