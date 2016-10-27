using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace Keyed_Plus
{
    public partial class Main : Form
    {
        public Main()
        {
            InitializeComponent();

            //Login...
            using (Login lf = new Login())
                if (lf.ShowDialog() == DialogResult.OK)
                {

                }
        }
    }
}
