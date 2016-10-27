using System;
using System.Drawing;
using System.Globalization;
using System.Linq;

namespace Keyed_Plus
{
    public struct Hyperlink : IEquatable<string>, IEquatable<Hyperlink>
    {
        public Color Color
        {
            get { return Color.FromArgb(BitConverter.ToInt32(BitConverter.GetBytes(color), 0)); }
            set { color = BitConverter.ToUInt32(BitConverter.GetBytes(value.ToArgb()), 0); }
        }
        public string Name
        {
            get { return name; }
            set { name = value; }
        }
        public int Identifier
        {
            get { return data[0]; }
        }

        private uint color;
        private string name;
        private string kind;
        private int[] data;

        private Hyperlink(string str)
        {
            string[] linkParts = str.Split(new char[] { '|' }, StringSplitOptions.RemoveEmptyEntries);
            string[] itemString = linkParts[1].Split(':');

            //Format...
            //linkParts[0] = color cAARRGGBB
            //linkParts[1] = item string <id>:<etc>
            //linkParts[2] = item Name h[Item Name]

            //Setup
            color = uint.Parse(linkParts[0].Substring(1), NumberStyles.HexNumber);
            name = linkParts[2].Substring(1);
            kind = itemString[0].Substring(1);
            data = new int[itemString.Length - 1];
            for (int i = 1; i < itemString.Length; i++)
                if (!int.TryParse(itemString[i], out data[i - 1]))
                    data[i - 1] = 0;
        }

        public bool Equals(string other)
        {
            return Equals(new Hyperlink(other));
        }
        public bool Equals(Hyperlink other)
        {
            //Prepare...
            bool equality = true;

            //Check...
            equality &= data.SequenceEqual(other.data); //Compare Data...
            equality &= (name == other.name);           //Compare Name...
            equality &= (kind == other.kind);           //Compare Kind...

            //Return
            return equality;
        }

        public static implicit operator Hyperlink(string str)
        {
            //Get...
            return new Hyperlink(str);
        }
        public static implicit operator string(Hyperlink link)
        {
            return link.ToString();
        }
    }
}
