#My watermark
Fozzy Hou, DB228980
##Installation
###Install perl Imager###
To install Imager with TIFF support, install libtiff first.
```
sudo apt-get install libtiff5 libtiff5-dev
```

Then install Imager main module using `cpan`
```
sudo cpan install Imager
```

After `Imager` installed, install `Imager::File::TIFF`
```
sudo cpan install Imager::File::TIFF
```
Notice: do not try to install on Mac, there are problems with it.

###Install Gtk2 library for perl###
```
sudo apt-get install libgtk2-perl
```
Alternatively, install using `cpan`
```
sudo cpan install Gtk2
```

##Program description

```
my %lenna_attr = get_attr($lenna, 'tiff');
my %baboon_attr = get_attr($baboon, 'bmp');
my %fruits_attr = get_attr($fruits, 'bmp');
```
get the size of images and the ratio of height over width

```
%tbl = maketbl();
%tbl_bin = map {$_ => substr unpack("B32", pack("N", $tbl{$_})), -6} keys %tbl;
```
generate a hash table for encoding/decoding, and convert the decimal table to binary format with 6 bits.

```
my $lenna_output = qq/lenna_watermarked.tiff/;
my $baboon_output = qq/baboon_watermarked.bmp/;
my $fruits_output = qq/fruits_watermarked.bmp/;

watermark($lenna, 'tiff', \%lenna_attr, $plaintext, \%tbl_bin, $lenna_output);
watermark($baboon, 'bmp', \%baboon_attr, $plaintext, \%tbl_bin, $baboon_output);
watermark($fruits, 'bmp', \%fruits_attr, $plaintext, \%tbl_bin, $fruits_output);
```
call function watermark to get the watermarked images.

```
#parameters: filename, filetype, image attr,  plaintext, binary table, outpu    t filename
 59 sub watermark{
 60         say "Encoding plaintext into image...";
 61         my $filename = shift;
 62         my $filetype = shift;
 63         my $image_attr_ref = shift;
 64         my %image_attr = %{$image_attr_ref};
 65         my $img = Imager->new();
 66         $img->read(file => $filename, type => $filetype) or die $img->errstr    ();
 67 
 68         my $watermark_seq = '';
 69         my $plaintext = shift;
 70         my $tbl_bin_ref = shift;
 71         my %tbl_bin = %{$tbl_bin_ref};
 72         my $save_filename = shift;
 73         foreach(split(//, $plaintext)){
 74                 die qq/illegal character encountered: $_/ if not exists $tbl    _bin{$_};
 75                 $watermark_seq = $watermark_seq . sprintf "%s", $tbl_bin{$_}    ;
 76         }
 77         say "watermark sequence for $plaintext is: $watermark_seq";
 78 
 79         #one character = 6 bits = 2 * one pixel(3 bits)
 80         $npixel = length($plaintext) * 2;
 81         @watermark_array = unpack("(A3)*", $watermark_seq);
 82 
 83         for my $i (0 .. $npixel - 1){
 84                 my ($x, $y) = get_position(\%image_attr, $i);
 85                 my ($r, $g, $b, $a) = $img->getpixel(x => $x, y => $y)->rgba    ();
 86                 my @bits = split(//, $watermark_array[$i]);
 87                 $r += ($bits[0]+=0) << 1;
 88                 $g += ($bits[1]+=0) << 1;
 89                 $b += ($bits[2]+=0) << 1;
 90                 my $pixel = Imager::Color->new(r => $r, g => $g, b => $b);
 91                 $img->setpixel(x => $x, y => $y, color => $pixel);
 92         }
 93         $img->write(file => $save_filename, type => $filetype) or die $img=>    errstr();

```
convert plaintext to watermark sequences, split the sequence to array of 3 bits to encode into pixel, write the pixel to file.

```
246 coefficient($lenna, $lenna_output, 'tiff', length($plaintext), \%tbl_bin);
247 print qq/\n/;
248 coefficient($baboon, $baboon_output, 'bmp', length($plaintext), \%tbl_bin);
249 print qq/\n/;
250 coefficient($fruits, $fruits_output, 'bmp', length($plaintext), \%tbl_bin);
```
calculate the cofficient and extract the watermark sequence.

```
141         my $origin_img = Imager->new();
142         my $processed_img = Imager->new();
143         $origin_img->read(file => $origin, type => $type) or die $origin_img    ->errstr();
144         $processed_img->read(file => $processed, type => $type) or die $proc    essed_img->errstr();
145 
146         my %origin_attr = get_attr($origin, $type);
147         my %processed_attr = get_attr($processed, $type);
148 
149         my @watermark_seq = ();
150         my @origin_seq = ();
151 
152         for my $i (0 .. $len * 2 - 1){
153                 my ($x, $y) = get_position(\%origin_attr, $i); #same size
154                 my ($pr, $pg, $pb, $pa) = $processed_img->getpixel(x => $x,     y => $y)->rgba();
155                 my ($or, $og, $ob, $oa) = $origin_img->getpixel(x => $x, y =    > $y)->rgba();
156                 my ($r, $g, $b) = ($pr - $or, $pg - $og, $pb - $ob);
157                 $r >>= 1;
158                 $g >>= 1;
159                 $b >>= 1;
160                 my $char = join('', $r, $g, $b);
161                 $watermark_seq[$i] = $char;
162                 $origin_seq[$i] = join('', get_watermark_bit($or), get_water    mark_bit($og), get_watermark_bit($ob));
163 
164         }
165         my $extracted_watermark = join('', @watermark_seq);
166         my $original_watermark = join('', @origin_seq);
167         say "extracted watermark sequence is $extracted_watermark";
168 
169         my $watermark_count = $extracted_watermark =~ tr/1/1/;
170         my $origin_count = $original_watermark =~ tr/1/1/;
171 
172         my $origin_avg = $origin_count * 1 / length($original_watermark);
173         my $extract_avg = $watermark_count * 1 / length($extracted_watermark    );
174         my ($fraction, $numerator1, $numerator2) = (0, 0, 0);
175         for my $i (0 .. length($original_watermark - 1)){
176                 $fraction += ((substr($extracted_watermark, $i, 1) + 0) - $e    xtract_avg) * ((substr($original_watermark, $i, 1) + 0) - $origin_avg);
177                 $numerator1 += ((substr($extracted_watermark, $i, 1) + 0) -     $extract_avg) **2;
178                 $numerator2 += ((substr($original_watermark, $i, 1) + 0) - $    origin_avg) **2;
179         }
180         $numerator1 = sqrt $numerator1;
181         $numerator2 = sqrt $numerator2;
182         my $corr = abs $fraction / ($numerator1 * $numerator2);
```
compare two images to get the difference at the watermark position.
the `get_watermark_bit` function is here:
```
190 sub get_watermark_bit{
191         my $bin = shift;
192         #only keep bit at watermark bit
193         $bin =$bin & 2;
194         return $bin>>1;
195 }
```
bitwise operation to get the watermark bit effciently.

finally, use `decode_from_tbl` to convert watermark sequence back to plaintext.
```
197 sub decode_from_tbl{
198         my $seq = shift;
199         my $hashref = shift;
200         my %tbl = %{$hashref};
201         my $plaintext = '';
202         foreach(unpack("(A6)*", $seq)){
203                 my $curr = $_;
204                 foreach(keys %tbl){
205                         $plaintext = $plaintext . $_ if $curr eq $tbl{$_};
206                 }
207         }
208         return $plaintext;
209 }
```

###ps
sorry for the mass that perl language caused, it is very quick to write but reads terrible.
