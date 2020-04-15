Public Class Form1

    Dim Lf, Tp, Rt, Bm, Ratio, Marg As Double
    ' Of the subtitle region (in picturebox): left, top, right, bottom;
    ' Of the original image and the picturebox: (de)magnification ratio; black margin caused by different aspect ratios (positive: top & bottom; negative: left & right)
    Public RGBImgs As String(), Folder As String
    ' Filenames of .jpeg images in the RGBImages folder; parent folder name
    Private picPen = New Pen(SystemColors.Highlight, 2)

    Private Sub Form1_Load(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles MyBase.Load
        Me.Icon = Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath)
        Lf = 0 : Tp = 0 : Rt = 640 : Bm = 480 ' whole region
        TextBox1.Text = Environment.CurrentDirectory
    End Sub

    Private Sub Button1_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles Button1.Click
        TextBox1.Text = TextBox1.Text.Replace("/", "\")
        If TextBox1.Text.Last = "\" Then TextBox1.Text = TextBox1.Text.Substring(0, TextBox1.Text.Length - 1) ' normalize
        Folder = TextBox1.Text ' fix the folder
        Try
            RGBImgs = IO.Directory.GetFiles(Folder & "\RGBImages", "*.jpeg") ' note: only files with .jpeg extension will be treated
        Catch ex As Exception
            MsgBox("No .jpeg image in this directory", MsgBoxStyle.Critical)
            Exit Sub
        End Try

        Dim img As New Bitmap(RGBImgs(0)) ' load the first RGBImage as an example
        ' Calculate mag ratio and margins
        If img.Height / img.Width < 0.75 Then ' margins at top & bottom
            Marg = 240 - 320 / img.Width * img.Height
            Ratio = 640 / img.Width
        Else
            Marg = 240 * img.Width / img.Height - 320 ' margins at left & right
            Ratio = 480 / img.Height
        End If
        Lf = 0 : Tp = 0 : Rt = img.Width * Ratio : Bm = img.Height * Ratio
        Label1.Text = 0 : Label2.Text = 0
        Label3.Tag = Rt : Label4.Tag = Bm ' maxima
        Label3.Text = img.Width : Label4.Text = img.Height ' full region

        PictureBox1.Image = img
        PictureBox1.Enabled = True

        Button2.Enabled = True
        Me.AcceptButton = Button2
        Button2.Focus()
        Button1.Enabled = False
        TextBox1.Enabled = False
        TextBox1.Text = "Please wait..."
        If MsgBox("Auto detect subtitle region boundary?", MsgBoxStyle.Question Or MsgBoxStyle.YesNo) = MsgBoxResult.Yes Then
            For i = 0 To img.Height - 1 Step 2 ' reduce sampling
                For j = 0 To img.Width - 1 Step 2
                    Dim c As Color = img.GetPixel(j, i)
                    If c.R < 240 AndAlso c.G < 240 And c.B < 240 Then ' detect blank region (allow error within 16)
                        If (Lf = 0 And Tp = 0) Then Label1.Text = j : Label2.Text = i : Lf = j * Ratio : Tp = i * Ratio
                        Label4.Text = i : Label3.Text = j
                    End If
                Next
            Next
            Rt = CInt(Label3.Text) * Ratio : Bm = CInt(Label4.Text) * Ratio
            PictureBox1.Refresh()
        End If
        Button1.Enabled = True
        TextBox1.Enabled = True
        TextBox1.Text = Folder
    End Sub

    Private Sub PictureBox1_MouseMove(ByVal sender As Object, ByVal e As System.Windows.Forms.MouseEventArgs) Handles PictureBox1.MouseMove, PictureBox1.MouseDown
        If e.Button = Windows.Forms.MouseButtons.Left Then ' left&top
            Lf = e.Location.X
            Tp = e.Location.Y
            If Marg > 0 Then Tp -= Marg Else Lf += Marg ' take into consideration the margins

            ' minima
            If Lf < 0 Then Lf = 0
            If Lf > Label3.Tag - 5 Then Lf = Label3.Tag - 5
            If Tp < 0 Then Tp = 0
            If Tp > Label4.Tag - 5 Then Tp = Label4.Tag - 5
            If Lf > Rt - 5 Then Lf = Rt - 5
            If Tp > Bm - 5 Then Tp = Bm - 5

            PictureBox1.Refresh()
            Label1.Text = Int(Lf / Ratio)
            Label2.Text = Int(Tp / Ratio)
        End If
        If e.Button = Windows.Forms.MouseButtons.Right Then ' right&bottom
            Rt = e.Location.X
            Bm = e.Location.Y
            If Marg > 0 Then Bm -= Marg Else Rt += Marg ' take into consideration the margins

            ' maxima
            If Rt > Label3.Tag Then Rt = Label3.Tag
            If Rt < 5 Then Rt = 5
            If Bm > Label4.Tag Then Bm = Label4.Tag
            If Bm < 5 Then Bm = 5
            If Tp > Bm - 5 Then Bm = Tp + 5
            If Lf > Rt - 5 Then Rt = Lf + 5
            PictureBox1.Refresh()
            Label3.Text = Int(Rt / Ratio)
            Label4.Text = Int(Bm / Ratio)
        End If
    End Sub

    Private Sub PictureBox1_Paint(ByVal sender As Object, ByVal e As System.Windows.Forms.PaintEventArgs) Handles PictureBox1.Paint
        Dim rect As New Rectangle(Lf + 1, Tp + 1, Rt - Lf - 2, Bm - Tp - 2)
        If Marg > 0 Then rect.Y += Marg Else rect.X -= Marg ' take into consideration the margins
        ' visualize the boundary
        e.Graphics.DrawRectangle(picPen, rect)
    End Sub

    Private Sub Button2_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles Button2.Click
        Me.Enabled = False
        TextBox1.Enabled = False
        TextBox1.Text = "Please wait..."
        My.Application.DoEvents()
        Form2.Show()
        TextBox1.Enabled = True
        TextBox1.Text = Folder
    End Sub
End Class
