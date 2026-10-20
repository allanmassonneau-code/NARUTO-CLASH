using System; using System.IO;
public static class WemAdpcm {
  static readonly int[] IDX={-1,-1,-1,-1,2,4,6,8,-1,-1,-1,-1,2,4,6,8};
  static readonly int[] STEP={7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767};
  public static string ToWav(string wem, string wav) {
    var w=File.ReadAllBytes(wem); int ch=0,rate=0,align=0; int dOff=-1,dLen=0;
    for(int q=12;q+8<=w.Length;){ string t=System.Text.Encoding.ASCII.GetString(w,q,4); int l=BitConverter.ToInt32(w,q+4);
      if(t=="fmt "){ch=BitConverter.ToUInt16(w,q+10);rate=BitConverter.ToInt32(w,q+12);align=BitConverter.ToUInt16(w,q+20);}
      if(t=="data"){dOff=q+8;dLen=Math.Min(l,w.Length-dOff);break;} q+=8+l+(l&1); }
    if(dOff<0||ch==0||align==0) return "bad";
    int cb=align/ch; int spb=(cb-4)*2+1; int blocks=dLen/align;
    var pcm=new short[blocks*spb*ch];
    for(int bI=0;bI<blocks;bI++) for(int c=0;c<ch;c++){ int o=dOff+bI*align+c*cb;
      int s=BitConverter.ToInt16(w,o); int ix=Math.Min(88,Math.Max(0,(int)w[o+2])); int n=bI*spb;
      pcm[(n++)*ch+c]=(short)s;
      for(int k=4;k<cb;k++) for(int h=0;h<2;h++){ int nib=h==0?(w[o+k]&15):(w[o+k]>>4); int st=STEP[ix];
        int d=st>>3; if((nib&1)!=0)d+=st>>2; if((nib&2)!=0)d+=st>>1; if((nib&4)!=0)d+=st; if((nib&8)!=0)d=-d;
        s=Math.Max(-32768,Math.Min(32767,s+d)); ix=Math.Min(88,Math.Max(0,ix+IDX[nib])); pcm[(n++)*ch+c]=(short)s; } }
    using(var f=new BinaryWriter(File.Create(wav))){ int bytes=pcm.Length*2;
      f.Write("RIFF".ToCharArray()); f.Write(36+bytes); f.Write("WAVEfmt ".ToCharArray()); f.Write(16); f.Write((short)1); f.Write((short)ch); f.Write(rate); f.Write(rate*ch*2); f.Write((short)(ch*2)); f.Write((short)16);
      f.Write("data".ToCharArray()); f.Write(bytes); foreach(var v in pcm) f.Write(v); }
    return ch+"ch "+rate+"Hz "+(pcm.Length/ch/(double)rate).ToString("0.00")+"s"; }
}