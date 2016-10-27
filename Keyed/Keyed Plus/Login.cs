using System;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

namespace Keyed_Plus
{
    public partial class Login : Form
    {
        public string Username
        {
            get { return usernameBox.Text; }
            set { usernameBox.Text = value; }
        }
        public byte[] PasswordHash
        {
            get { return passwordHash; }
            set { passwordHash = value; }
        }

        private byte[] passwordHash = new byte[0];

        public Login()
        {
            InitializeComponent();

            //Setup
            usernameBox.Text = Properties.Settings.Default.defaultUsername;
            passwordBox.Text = new string('•', Properties.Settings.Default.passwordLength);
            passwordHash = Convert.FromBase64String(Properties.Settings.Default.passwordHash);
            rememberBox.Checked = Properties.Settings.Default.rememberCredentials;
        }

        private void exitButton_Click(object sender, EventArgs e)
        {
            Application.Exit();
        }

        private void loginButton_Click(object sender, EventArgs e)
        {
            //Hash...
            if (!string.IsNullOrEmpty(passwordBox.Text))
                using (SHA256 hashFunc = SHA256.Create())
                    passwordHash = hashFunc.ComputeHash(Encoding.UTF8.GetBytes(passwordBox.Text));

            //Check...
            if (passwordHash.Length > 0)
            {
                if (!rememberBox.Checked)
                {
                    //Clear Settings...
                    Properties.Settings.Default.passwordLength = 0;
                    Properties.Settings.Default.defaultUsername = string.Empty;
                    Properties.Settings.Default.passwordHash = string.Empty;
                }
                else
                {
                    //Set Settings...
                    Properties.Settings.Default.defaultUsername = usernameBox.Text;
                    Properties.Settings.Default.passwordHash = Convert.ToBase64String(passwordHash);
                    Properties.Settings.Default.passwordLength = passwordBox.Text.Length;
                }

                //Save
                Properties.Settings.Default.rememberCredentials = rememberBox.Checked;
                Properties.Settings.Default.Save();
            }
        }
    }
}
