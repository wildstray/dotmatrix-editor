#!/usr/bin/perl

# dotmatrix editor http://code.google.com/p/dotmatrix-editor/

use strict;
use warnings;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
#use Data::Dumper;

# global variables

my $w = 8;		# default width
my $h = 8;		# default height
my $max_w = 16;		# max width
my $max_h = 16;		# max height
my $min_w = 4;		# min width
my $min_h = 4;		# min height
my $win_w = 200;	# window base width (except editor and result)
my $win_h = 100;	# window base height (except editor and result)
my $dir = 0; 		# scanline direction: defaults horizontal
my $byte_size = 8;	# bytes of 8 bits... you wan't change this!
my $def_type = "uint%d_t PROGMEM";		# default C array type
my $def_name = "myarray";			# default C array name
my @c_files = ("*.c", "*.h", "*.cpp", "*.pde"); # C file extensions
my $font = Gtk2::Pango::FontDescription->from_string('Monospace 8');

my @bitmatrix = ();
my @matrix = ();
my @arrays = ();

my $loadfile;
my $settings;
my $editor;
my $result;
my $text;
my $hbox;
my $vbox;
my $window;
my $a_name;
my $a_type;

# Function definitions

sub bin { return unpack("N", pack("B32", substr("0" x 32 . shift, -32))); }
sub dec2hex { my $hex = unpack("H8", pack("N", shift)); my $zeros = "0" x (8 - int(shift)); $hex =~ s/$zeros//; return $hex; }
sub dec2bin { my $bin = unpack("B32", pack("N", shift)); my $zeros = "0" x (32 - int(shift)); $bin =~ s/$zeros//; return $bin; }
sub log2 { return int(log(int(shift))/log(2)); }
sub min { my ($a, $b) = @_; return ($a < $b) ? $a : $b; }
sub max { my ($a, $b) = @_; return ($a > $b) ? $a : $b; }

sub delete_event
{
    Gtk2->main_quit;
    return FALSE;
}

sub bytes
{
    my ($cols, $rows) = @_;

    return 1 + (($dir) ? int(($rows-1) / $byte_size) : int(($cols-1) / $byte_size));
}

# editor buttons common callback (udates matrix)

sub callback {
    my ($widget, $data) = @_;
    my ($x, $y) = @$data;

    my $label = ($widget->get_active()) ? '*' : ' ';
    $widget->set_label($label);
    $bitmatrix[$y][$x] = ($widget->get_active()) ? 1 : 0;
    if ($dir) {
	my @tmp = ();
	for (my $y = 0; $y < $h; $y++) {
	    push @tmp, $bitmatrix[$y][$x];
	}
	$matrix[$x] = bin(join("", @tmp));
    } else {
	$matrix[$y] = bin(join("", @{$bitmatrix[$y]}));
    }
    #print Dumper (@bitmatrix);
    #print Dumper (@matrix);
    redraw_result();
    redraw_text();
    return;
}

# Switch scaline direction (doesn't zeroize matrix)

sub switch {
    my ($widget, $data) = @_;

    $dir = $widget->get_active();
    load_matrix();
    redraw_editor();
    redraw_result();
    redraw_text();
    return;
}

# Reset editor (zeroize matrix)

sub clear
{
    my ($widget, $data) = @_;
    
    undef $a_type;
    undef $a_name;
    init_bitmatrix($w, $h);
    init_matrix($w, $h);
    redraw_loadfile();
    redraw_editor();
    redraw_result();
    redraw_text();
    return;
}

# Open and load a file

sub copen
{
    my ($widget, $data) = @_;
    my ($combof1, $combof2) = @$data;
    
    my $filename = $widget->get_filename();
    
    @arrays = ();
    cparse($filename);
    
    $combof1->clear();
    $combof2->clear();
    
    my $model = Gtk2::ListStore->new ('Glib::String');
    foreach(@arrays)
    { 
	$model->set($model->append, 0, $_->{key});
    }
    
    $combof1->set_model($model);
    #$combof1->set_wrap_width(16);

    my $renderer1 = Gtk2::CellRendererText->new;
    $combof1->pack_start ($renderer1, FALSE);
    $combof1->add_attribute ($renderer1, text => 0);

    $combof1->set_active(0);
    
    return;
}

# parse C file and populate arrays

sub cparse
{
    my ($filename) = @_;

    return if !$filename;

    open my $fh, '<', $filename;
    local $/ = undef;
    my $buffer = <$fh>;
    close $fh;
    
    $buffer =~ s!^$!!gms;		# cut empty lines
    $buffer =~ s!//.*?$!!gms;		# cut C // comments
    $buffer =~ s!/\*.*?\*/!!gms;	# cut C /* */ comments
    $buffer =~ s!#.*?$!!gms;		# cut CPP directives
    $buffer =~ s!^\s*!!gms;		# remove leading spaces

    # parse array definitions... far from beeing perfect and error proof...

    while($buffer =~ m!(?:\n*(?<key>.*?)\s*=\s*)(?<value>{(?:[^{}]++|(?2))*};*)!gms) {
	my $key = $+{key};
	my $value = $+{value};
	$value =~ s/[\n|\s]//g; 	# remove spaces and line feeds
	$key =~ m!^(?<type>.+)\s(?<key>.+)(:?\[(?<size>\d+)\]\[(?<len>\d+)\])$!;
	$key = $+{key};
	my $type = $+{type};
	my $size = $+{size};
	my $len = $+{len};
	my @data = ();
	while ($value =~ m!(:?{(?<value>[^{}]+)})+!g) {
	    my @values = split(',', $+{value});
	    for (my $i = 0; $i < @values; $i++)
	    {
		my $value = $values[$i];
		if ($value =~ s!^0b(\d+)$!$1!) {
		    $values[$i] = bin($value);
		} elsif ($value =~ s!^0x([a-fA-F0-9]+)$!$1!) {
		    $values[$i] = hex($value);
		} elsif ($value =~ m!^\d+$!) {
		    $values[$i] = int($value);
		}
	    }
	    push @data, [@values];
	}
	push @arrays, {key => $key, type => $type, size => $size, len => $len, data => \@data};
    }
    #print Dumper (@arrays);
}

# choose C array, detect size and create fonts/bitmaps preview

sub cload1
{
    my ($widget, $data) = @_;
    my ($combof1, $combof2) = @$data;

    return if !@arrays;

    my $key = $combof1->get_active();

    my @data = $arrays[$key]->{data};
    my $size = $arrays[$key]->{size};
    my $len = $arrays[$key]->{len};
    $a_type = $arrays[$key]->{type};
    $a_name = $arrays[$key]->{key};

    # width and height detection logic 

    my $max = (reverse sort { $a <=> $b } map @$_, @{$data[0]})[0];
    my $bytes = ($max) ? (1 + int(log2($max) / $byte_size)) : 1;
    
    #$dir = ($len < $byte_size) ? 1 : 0;
    $dir = ($len <= $byte_size) ? 1 : 0;
    if ($dir) {
	$w = $len;
	$h = $bytes * $byte_size;
    } else {
	$w = $bytes * $byte_size;
	$h = $len;
    }
    #print "w: $w h: $h dir $dir\n";

    $combof2->clear();

    my $model = preview($key);
    $combof2->set_model($model);
    #$combof2->set_wrap_width(16);

    my $renderer1 = Gtk2::CellRendererText->new;
    $combof2->pack_start ($renderer1, FALSE);
    $combof2->add_attribute ($renderer1, text => 0);
    my $renderer2 = Gtk2::CellRendererPixbuf->new;
    $combof2->pack_start ($renderer2, TRUE);
    $combof2->add_attribute ($renderer2, pixbuf => 1);

    $combof2->set_active(0);
}

# choose C array index and load matrix

sub cload2
{
    my ($widget, $data) = @_;
    my ($combof1, $combof2) = @$data;

    my $key = $combof1->get_active();
    my $index = $combof2->get_active();

    my @data = $arrays[$key]->{data};

    @matrix = ();
    @matrix = @{$data[0][$index]};
    #print Dumper(@matrix);

    init_bitmatrix($w, $h);
    load_bitmatrix();
    redraw_settings(); 
    redraw_editor(); 
    redraw_result();
    redraw_text();
}

# Generate preview of bitmaps/fonts for combobox

sub preview {
    my ($key) = @_;

    my $model = Gtk2::ListStore->new ('Glib::String', 'Gtk2::Gdk::Pixbuf');
    my $size = $arrays[$key]->{size};
    for (my $i = 0; $i < $size; $i++)
    {
	my @data = $arrays[$key]->{data};
	my @tmpmatrix = ();
	@tmpmatrix = @{$data[0][$i]};
	#print Dumper(@tmpmatrix);
	my @xpm = ();
	push @xpm, "$w $h 2 1";
	push @xpm, "0 c None";
	push @xpm, "1 c Black";
	my $bytes = bytes($w, $h);
	if ($dir) {
	    for (my $x = 0; $x < $h; $x++) {
		my $tmp;
		for (my $y = 0; $y < $w; $y++)
		{
		    $tmp .= substr (dec2bin($tmpmatrix[$y], $bytes * $byte_size), $x, 1);
		}
		push @xpm, $tmp;
	    }
	} else {
	    for (my $y = 0; $y < $h; $y++)
	    {
		push @xpm, dec2bin($tmpmatrix[$y], $bytes * $byte_size);
	    }
	}
	#print Dumper(@xpm);
        my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_xpm_data(@xpm);
	$model->set($model->append, 0, $i, 1, $pixbuf);
    }
    return $model;
}

# Resize editor (zeroize matrix, loaded file arrays)

sub resize
{
    my ($widget, $data) = @_;

    init_bitmatrix($w, $h);
    init_matrix($w, $h);
    redraw_loadfile(); 
    redraw_editor(); 
    redraw_result();
    redraw_text();
}

# Define and zeroize bitmatrix (editor buttons status)

sub init_bitmatrix
{
    my ($cols, $rows) = @_;

    @bitmatrix = ();
    for (my $y = 0; $y < $rows; $y++) {
        for (my $x = 0; $x < $cols; $x++) {
	    $bitmatrix[$y][$x] = 0;
        }
    }
}

# Define and zeroize matrix

sub init_matrix
{
    my ($cols, $rows) = @_;

    @matrix = ();
    if ($dir) {
	for (my $x = 0; $x < $cols; $x++) {
	    $matrix[$x] = 0;
	}
    } else {
	for (my $y = 0; $y < $rows; $y++) {
	    $matrix[$y] = 0;
	}
    }
}

# load matrix from bitmatrix (editor buttons status)

sub load_matrix
{
    if ($dir)
    {
	for (my $x = 0; $x < $w; $x++)
	{
	    my @tmp = ();
	    for (my $y = 0; $y < $h; $y++) {
		push @tmp, $bitmatrix[$y][$x];
	    }
	    $matrix[$x] = bin(join("", @tmp));
	}
    } else {
	for (my $y = 0; $y < $h; $y++)
	{
	    $matrix[$y] = bin(join("", @{$bitmatrix[$y]}));
	}
    }
}

# load bitmatrix (editor buttons status) from matrix 

sub load_bitmatrix
{
    my $bytes = bytes($w, $h);
    if ($dir) {
	for (my $x = 0; $x < $w; $x++) {
	    my @tmp = ();
	    @tmp = split('', dec2bin($matrix[$x], $bytes * $byte_size));
	    for (my $y = 0; $y < $h; $y++)
	    {
		$bitmatrix[$y][$x] = $tmp[$y];
	    }
	}
    } else {
	for (my $y = 0; $y < $h; $y++)
	{
	    @{$bitmatrix[$y]} = split('', dec2bin($matrix[$y], $bytes * $byte_size));
	}
    }
    #print Dumper (@bitmatrix);
}

# Draw editor (and load bitmatrix)

sub draw_editor {
    my ($cols, $rows) = @_;

    my $frame = Gtk2::Frame->new('Editor');
    $frame->set_border_width(4);
    my $table = Gtk2::Table->new($rows+1, $cols+1, FALSE);
    $table->set_border_width(8);

    for (my $x = 0; $x < $cols; $x++) {
	my $x_lab = ($dir) ? $x : $w - $x-1;
	my $x_hex = '0x' . dec2hex($x_lab, 2);
        my $label = Gtk2::Label->new($x_hex);
	$label->modify_font($font);
        $label->set_angle(90);
        $label->set_alignment(0.5, 0);
	$table->attach_defaults($label, $x, $x+1, 0, 1);
    }

    for (my $y = 0; $y < $rows; $y++) {
	for (my $x = 0; $x < $cols; $x++) {
	    my $togglebutton = Gtk2::ToggleButton->new(' ');
	    $table->attach_defaults($togglebutton, $x, $x+1, $y+1, $y+2);
	    $togglebutton->set_active(TRUE) if ($bitmatrix[$y][$x]);
	    $togglebutton->set_label('*')  if ($bitmatrix[$y][$x]);
	    $togglebutton->signal_connect('toggled'=>\&callback, [$x, $y]);
	}
	my $y_lab = ($dir) ? $h - $y-1 : $y;
	my $y_hex = '0x' . dec2hex($y_lab, 2);
	my $label = Gtk2::Label->new($y_hex);
        $label->modify_font($font);
	$table->attach_defaults($label, $cols, $cols+1, $y+1, $y+2);
    }

    $frame->add($table);
    return $frame;
}

# Redraw editor (eg. for reloading matrix, direction or size change)

sub redraw_editor
{
    $editor->destroy;
    $editor = draw_editor($w, $h);

    $hbox->pack_start($editor,TRUE,TRUE,0);
    $window->resize($win_w + $w*20, $win_h + $h*20);
    $window->show_all;
}

# Draw results frame

sub draw_result
{
    my ($cols, $rows) = @_;
    my $frame = Gtk2::Frame->new('Resulting array');
    $frame->set_border_width(4);
    my $len = ($dir) ? $cols : $rows;
    my $bytes = bytes($cols, $rows);
    my $table = Gtk2::Table->new($len+1, 1, FALSE);
    $table->set_border_width(8);
    my $label = Gtk2::Label->new();
    $label->modify_font($font);
    $table->attach_defaults($label, 0, 1, 0, 1);
    for (my $i = 0; $i < $len; $i++) {
        my $hex = "0x" . dec2hex($matrix[$i], $bytes * 2);
        my $bin = "0b" . dec2bin($matrix[$i], $bytes * $byte_size);
        $label = Gtk2::Label->new("$hex $bin");
        $label->modify_font($font);
        $table->attach_defaults($label, 0, 1, $i+1, $i+2);
    }
    $frame->add($table);
    return $frame;
}

# Redraw results (eg. for reloading matrix, direction or size change)

sub redraw_result
{
    $result->destroy;
    $result = draw_result($w, $h);
    $hbox->pack_end($result,FALSE,FALSE,0);
    $window->show_all;
}

# Draw settings frame

sub draw_settings
{
    my $frame = Gtk2::Frame->new('Settings');
    $frame->set_border_width(4);

    my $adjx = Gtk2::Adjustment->new ($w, $min_w, $max_w, 1, 1, 0);
    my $adjy = Gtk2::Adjustment->new ($h, $min_h, $max_h, 1, 1, 0);
    my $spinx = Gtk2::SpinButton->new($adjx, 1, 0);
    my $spiny = Gtk2::SpinButton->new($adjy, 1, 0);
    $spinx->signal_connect('value-changed'=> sub {$w = $spinx->get_value(); $h = $spiny->get_value(); resize(); });
    $spiny->signal_connect('value-changed'=> sub {$w = $spinx->get_value(); $h = $spiny->get_value(); resize(); });

    my $labx = Gtk2::Label->new('Horizontal pixel:');
    $labx->modify_font($font);

    my $laby = Gtk2::Label->new('Vertical pixel:');
    $laby->modify_font($font);

    my $vboxx = Gtk2::VBox->new(FALSE,5);
    $vboxx->add($labx);
    $vboxx->add($spinx);

    my $vboxy = Gtk2::VBox->new(FALSE,5);
    $vboxy->add($laby);
    $vboxy->add($spiny);

    my $buttonc = Gtk2::Button->new('Reset editor');
    $buttonc->signal_connect('clicked'=>\&clear);

    my $labd = Gtk2::Label->new('Byte/word direction:');
    $labd->modify_font($font);
    my $combod = Gtk2::ComboBox->new_text;
    $combod->append_text('horizontal');
    $combod->append_text('vertical');
    $combod->set_active($dir);
    $combod->signal_connect('changed'=>\&switch);

    my $vboxd = Gtk2::VBox->new(FALSE,5);
    $vboxd->add($labd);
    $vboxd->add($combod);

    my $vboxs = Gtk2::VBox->new(FALSE,5);
    $vboxs->set_border_width(4);
    $vboxs->pack_start($vboxx,FALSE,FALSE,4);
    $vboxs->pack_start($vboxy,FALSE,FALSE,4);
    $vboxs->pack_start($vboxd,FALSE,FALSE,4);
    $vboxs->pack_end($buttonc,FALSE,FALSE,4);
    $frame->add($vboxs);

    return $frame;
}

# Redraw settings frame (eg. load from file)

sub redraw_settings
{
    $settings->destroy;
    $settings = draw_settings($w, $h);
    $hbox->pack_start($settings,FALSE,FALSE,0);
    $window->show_all;
}

# Draw text frame

sub draw_text
{
    my ($cols, $rows) = @_;

    my $len = ($dir) ? $cols : $rows;
    my $bytes = bytes($cols, $rows);

    $a_name = $def_name if !$a_name;
    $a_type = sprintf($def_type, $bytes * $byte_size) if !$a_type;
    my $text = "$a_type $a_name [1][$len] = {\n\t{ ";
    for (my $i = 0; $i < $len; $i++) {
        my $hex = "0x" . dec2hex($matrix[$i], $bytes * 2);
        $text .= "\n\t  " if !($i % 8) && $i;
        $text .= "$hex, ";
    }
    $text .= "},\n};";

    my $frame = Gtk2::Frame->new('Resulting C array');
    $frame->set_border_width(4);

    my $buffer = Gtk2::TextBuffer->new();
    my $iter = $buffer->get_start_iter;
    $buffer->insert_with_tags_by_name ($iter, $text);

    my $tview = Gtk2::TextView->new_with_buffer($buffer);
    $tview->set_editable(FALSE);
    $tview->set_border_width(4);

    $frame->add($tview);
    return $frame;
}

# Redraw text frame

sub redraw_text
{
    $text->destroy;
    $text = draw_text($w, $h);
    $vbox->pack_end($text,FALSE,FALSE,0);
    $window->show_all;
}

# Draw load from file frame

sub draw_loadfile 
{
    my $filechooser = Gtk2::FileChooserButton->new ('Select a file' , 'open');
    my $filter = Gtk2::FileFilter->new();
    foreach (@c_files) { $filter->add_pattern($_); }
    $filechooser->set_filter($filter);

    my $frame = Gtk2::Frame->new('Load from file');
    $frame->set_border_width(4);
    my $combof1 = Gtk2::ComboBox->new_text;
    my $combof2 = Gtk2::ComboBox->new_text;
    my $hboxf = Gtk2::HBox->new(FALSE,5);
    $hboxf->set_border_width(4);
    $filechooser->signal_connect('selection-changed'=>\&copen,[$combof1,$combof2]);
    $combof1->signal_connect('changed'=>\&cload1,[$combof1,$combof2]);
    $combof2->signal_connect('changed'=>\&cload2,[$combof1,$combof2]);
    $hboxf->add($filechooser);
    $hboxf->add($combof1);
    $hboxf->add($combof2);
    $frame->add($hboxf);
    return $frame;
}

# Redraw load from file frame

sub redraw_loadfile
{
    $loadfile->destroy;
    $loadfile = draw_loadfile();
    $vbox->pack_start($loadfile,FALSE,FALSE,0);
    $vbox->reorder_child($loadfile,0);
    $window->show_all;
}

# Main window definition

$window = Gtk2::Window->new('toplevel');
$window->set_title("Dotmatrix fonts and bitmaps editor");
$window->signal_connect(delete_event => \&delete_event);
$window->set_border_width(8);
$window->set_resizable(FALSE);

# Show layout of main window, init editor and Gtk main

init_bitmatrix($w, $h);
init_matrix($w, $h);

$loadfile = draw_loadfile();
$settings = draw_settings($w, $h);
$editor = draw_editor($w, $h);
$result = draw_result($w, $h);
$text = draw_text($w, $h);

$hbox = Gtk2::HBox->new(FALSE,5);
$hbox->add($settings);
$hbox->add($editor);
$hbox->add($result);

$vbox = Gtk2::VBox->new(FALSE,5);
$vbox->pack_start($loadfile,FALSE,FALSE,0);
$vbox->pack_start($hbox,FALSE,FALSE,0);
$vbox->pack_end($text,FALSE,FALSE,0);

$window->add($vbox);
$window->show_all;

Gtk2->main;

0;
