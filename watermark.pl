#!/usr/bin/env perl

use Imager;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use Gtk2::Gdk::Keysyms;
use utf8;
use Data::Dumper;
use POSIX;
use warnings;
use feature qq/say/;


$Data::Dumper::Sortkeys = 1;

sub maketbl{
	my %tbl;
	
	#spacing
	$tbl{' '} = 0;

	#numeric
	foreach('0'..'9'){
		$tbl{$_} = ord($_) - ord('0') + 1;
	}
	#alphabet
	foreach('A'..'Z'){
		$tbl{$_} = ord($_) - ord('A') + 11;
	}

	#symbols
	$tbl{'?'} = $tbl{'Z'} + 1;
	$tbl{'!'} = $tbl{'?'} + 1;

	return %tbl;
}

sub calratio{
	my $hashref = shift;
	$hashref->{ratio} = $hashref->{height} / $hashref->{width};
}

sub get_plaintext_size{
	my $hashref = shift;
	my $length = shift;
	my $width = sqrt $length / $hashref->{ratio};
	my $height = $width * $hashref->{ratio};
	return (ceil($height), ceil($width));
}

#(x, y) means (width, height)
sub get_position{
	my $hashref = shift;
	my $index = shift;
	my ($i, $j) = (0, $index);
	while($j >= $hashref->{height}){
		$j -= $hashref->{height};
		die qq/data is too long to embed into image./ if(++$i > $hashref->{width});
	}
	return ($i, $j);
}

#parameters: filename, filetype, image attr,  plaintext, binary table, output filename
sub watermark{
	say "Encoding plaintext into image...";
	my $filename = shift;
	my $filetype = shift;
	my $image_attr_ref = shift;
	my %image_attr = %{$image_attr_ref};
	my $img = Imager->new();
	$img->read(file => $filename, type => $filetype) or die $img->errstr();

	my $watermark_seq = '';
	my $plaintext = shift;
	my $tbl_bin_ref = shift;
	my %tbl_bin = %{$tbl_bin_ref};
	my $save_filename = shift;
	foreach(split(//, $plaintext)){
		die qq/illegal character encountered: $_/ if not exists $tbl_bin{$_};
		$watermark_seq = $watermark_seq . sprintf "%s", $tbl_bin{$_};
	}
	say "watermark sequence for $plaintext is: $watermark_seq";

	#one character = 6 bits = 2 * one pixel(3 bits)
	$npixel = length($plaintext) * 2;
	@watermark_array = unpack("(A3)*", $watermark_seq);

	for my $i (0 .. $npixel - 1){
		my ($x, $y) = get_position(\%image_attr, $i);
		my ($r, $g, $b, $a) = $img->getpixel(x => $x, y => $y)->rgba();
		my @bits = split(//, $watermark_array[$i]);
		$r += ($bits[0]+=0) << 1;
		$g += ($bits[1]+=0) << 1;
		$b += ($bits[2]+=0) << 1;
		my $pixel = Imager::Color->new(r => $r, g => $g, b => $b);
		$img->setpixel(x => $x, y => $y, color => $pixel);
	}	
	$img->write(file => $save_filename, type => $filetype) or die $img=>errstr();
	say "Encoding finished, output file is $save_filename";
	say "Displaying image...";
	my $window = Gtk2::Window->new("toplevel");
	$window->set_title("my watermark");
	$window->signal_connect('delete_event',sub{Gtk2::main_quit;});
	my $hbox = Gtk2::HBox->new;
	my $vbox1 = Gtk2::VBox->new;
	my $vbox2 = Gtk2::VBox->new;
	my $pbuf1 = Gtk2::Gdk::Pixbuf->new_from_file_at_size($filename, $image_attr{width}, $image_attr{height});
	my $image1 = Gtk2::Image->new_from_pixbuf($pbuf1);
	my $pbuf2 = Gtk2::Gdk::Pixbuf->new_from_file_at_size($save_filename, $image_attr{width}, $image_attr{height});
	my $image2 = Gtk2::Image->new_from_pixbuf($pbuf2);
	my $label1 = Gtk2::Label->new("origin image");
	my $label2 = Gtk2::Label->new("processed image");
	$vbox1->add($image1);
	$vbox1->add($label1);
	$vbox2->add($image2);
	$vbox2->add($label2);
	$hbox->add($vbox1);
	$hbox->add($vbox2);
	$window->add($hbox);
	$window->show_all;
	Gtk2->main;
}

#filename, type
sub get_attr{
	my $img = Imager->new();

	$img->read(file=> shift, type=> shift) or die $img->errstr();
	my %img_attr = (
		'width'		=> $img->getwidth,
		'height'	=> $img->getheight
	);

	calratio(\%img_attr);
	return %img_attr;
}

sub coefficient{
	say "Calculating coefficients and decoding plaintext from image...";
	my $origin = shift;
	my $processed = shift;
	my $type = shift;
	my $len = shift;
	my $tbl_bin_ref = shift;
	my %tbl_bin = %{$tbl_bin_ref};
	my $origin_img = Imager->new();
	my $processed_img = Imager->new();
	$origin_img->read(file => $origin, type => $type) or die $origin_img->errstr();
	$processed_img->read(file => $processed, type => $type) or die $processed_img->errstr();

	my %origin_attr = get_attr($origin, $type);
	my %processed_attr = get_attr($processed, $type);

	my @watermark_seq = ();
	my @origin_seq = ();

	for my $i (0 .. $len * 2 - 1){
		my ($x, $y) = get_position(\%origin_attr, $i); #same size
		my ($pr, $pg, $pb, $pa) = $processed_img->getpixel(x => $x, y => $y)->rgba();
		my ($or, $og, $ob, $oa) = $origin_img->getpixel(x => $x, y => $y)->rgba();
		my ($r, $g, $b) = ($pr - $or, $pg - $og, $pb - $ob);
		$r >>= 1;
		$g >>= 1;
		$b >>= 1;
		my $char = join('', $r, $g, $b);
		$watermark_seq[$i] = $char;
		$origin_seq[$i] = join('', get_watermark_bit($or), get_watermark_bit($og), get_watermark_bit($ob));
		
	}
	my $extracted_watermark = join('', @watermark_seq);
	my $original_watermark = join('', @origin_seq);
	say "extracted watermark sequence is $extracted_watermark";

	my $watermark_count = $extracted_watermark =~ tr/1/1/;
	my $origin_count = $original_watermark =~ tr/1/1/;
	
	my $origin_avg = $origin_count * 1 / length($original_watermark);
	my $extract_avg = $watermark_count * 1 / length($extracted_watermark);
	my ($fraction, $numerator1, $numerator2) = (0, 0, 0);
	for my $i (0 .. length($original_watermark - 1)){
		$fraction += ((substr($extracted_watermark, $i, 1) + 0) - $extract_avg) * ((substr($original_watermark, $i, 1) + 0) - $origin_avg);
		$numerator1 += ((substr($extracted_watermark, $i, 1) + 0) - $extract_avg) **2;
		$numerator2 += ((substr($original_watermark, $i, 1) + 0) - $origin_avg) **2;
	}
	$numerator1 = sqrt $numerator1;
	$numerator2 = sqrt $numerator2;
	my $corr = abs $fraction / ($numerator1 * $numerator2);
	say "The coefficient of $origin is $corr.";
	my $plaintext = decode_from_tbl($extracted_watermark, \%tbl_bin);
	say "The retrieved plaintext from $processed is $plaintext";
	say "Decoding done.";

}

sub get_watermark_bit{
	my $bin = shift;
	#only keep bit at watermark bit
	$bin =$bin & 2;
	return $bin>>1;
}

sub decode_from_tbl{
	my $seq = shift;
	my $hashref = shift;
	my %tbl = %{$hashref};
	my $plaintext = '';
	foreach(unpack("(A6)*", $seq)){
		my $curr = $_;
		foreach(keys %tbl){
			$plaintext = $plaintext . $_ if $curr eq $tbl{$_};
		}
	}
	return $plaintext;
}

my $lenna = qq/lena512color.tiff/;
my $baboon = qq/baboon.bmp/;
my $fruits = qq/fruits.bmp/;

print '*'x70 . qq/\n/;
print qq/Welcome to My Watermarking!\n/;

print qq/Please enter the plaintext:\n> /;
my $plaintext = <STDIN>;
chomp $plaintext;

my %lenna_attr = get_attr($lenna, 'tiff');
my %baboon_attr = get_attr($baboon, 'bmp');
my %fruits_attr = get_attr($fruits, 'bmp');


%tbl = maketbl();
%tbl_bin = map {$_ => substr unpack("B32", pack("N", $tbl{$_})), -6} keys %tbl;

say "encoding table:";
foreach(sort keys %tbl){
	say "'$_' =>\t$tbl{$_}\t(dec)\t=>\t$tbl_bin{$_}(bin)";
}

my $lenna_output = qq/lenna_watermarked.tiff/;
my $baboon_output = qq/baboon_watermarked.bmp/;
my $fruits_output = qq/fruits_watermarked.bmp/;

watermark($lenna, 'tiff', \%lenna_attr, $plaintext, \%tbl_bin, $lenna_output);
print qq/\n/;
watermark($baboon, 'bmp', \%baboon_attr, $plaintext, \%tbl_bin, $baboon_output);
print qq/\n/;
watermark($fruits, 'bmp', \%fruits_attr, $plaintext, \%tbl_bin, $fruits_output);
print qq/\n/;

coefficient($lenna, $lenna_output, 'tiff', length($plaintext), \%tbl_bin);
print qq/\n/;
coefficient($baboon, $baboon_output, 'bmp', length($plaintext), \%tbl_bin);
print qq/\n/;
coefficient($fruits, $fruits_output, 'bmp', length($plaintext), \%tbl_bin);
print '*'x70 . qq/\n/;
