#use strict
use warnings;
use Glib qw/TRUE FALSE/;
use Gtk2 '-init';
use Data::Dumper;

# Pango is not portable (eg. doesn't compile under Windows)
#use Pango;
#my $font = Pango::FontDescription->from_string('Monospace 8');
my $font;

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
my @c_files = ("*.c", "*.h", "*.cpp", "*.pde"); # C file extensions

# global variables

my @bitmatrix = ();
my @matrix = ();
my @arrays = ();

my $settings;
my $editor;
my $result;
my $hbox;
my $vbox;
my $window;

# Function definitions

sub bin { return unpack("N", pack("B32", substr("0" x 32 . shift, -32))); }
sub dec2hex { $hex = unpack("H8", pack("N", shift)); $zeros = "0" x (8 - int(shift)); $hex =~ s/$zeros//; return $hex; }
sub dec2bin { $bin = unpack("B32", pack("N", shift)); $zeros = "0" x (32 - int(shift)); $bin =~ s/$zeros//; return $bin; }
sub log2 { return int(log(int(shift))/log(2)); }

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
    return;
}

# Switch scaline direction (doesn't zeroize matrix)

sub switch {
    my ($widget, $data) = @_;

    $dir = $widget->get_active();
    load_matrix();
    redraw_editor();
    redraw_result();
    return;
}

# Reset editor (zeroize matrix)

sub clear
{
    my ($widget, $data) = @_;
    
    init_bitmatrix($w, $h);
    init_matrix($w, $h);
    redraw_editor();
    redraw_result();
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
    
    foreach(@arrays)
    { 
	$combof1->remove_text(0);
    }

    foreach(@arrays)
    { 
	$combof1->append_text($_->{key});
    }
    
    return;
}

# parse C file and populate arrays

sub cparse
{
    my ($filename) = @_;

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
	my $key = $+{key}, $value = $+{value};
	$value =~ s/[\n|\s]//g; 	# remove spaces and line feeds
	$key =~ m!^.*\s(?<key>.+)(:?\[(?<size>\d+)\]\[(?<len>\d+)\])$!;
	$key = $+{key};
	my $size = $+{size};
	my $len = $+{len};
	my @data = ();
	while ($value =~ m!(:?{(?<value>[^{}]+)})+!g) {
	    my @values = split(',', $+{value});
	    for ($i = 0; $i < @values; $i++)
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
	push @arrays, {key => $key, size => $size, len => $len, data => \@data};
    }
    #print Dumper (@arrays);
}

# choose C array name

sub cload1
{
    my ($widget, $data) = @_;
    my ($combof1, $combof2) = @$data;

    my $key = $combof1->get_active();
    my $size = $arrays[$key]->{size};

    for (my $i = 0; $i < 256; $i++)
    {
	$combof2->remove_text(0);
    }
    for (my $i = 0; $i < $size; $i++)
    {
	$combof2->append_text($i);
    }
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
    my $len = $arrays[$key]->{len};
    
    @matrix = ();
    @matrix = @{$data[0][$index]};
    #print Dumper(@matrix);

    # width and height detection logic 

    my $max = (reverse sort { $a <=> $b } @matrix)[0];
    my $bytes = ($max) ? (1 + int(log2($max) / $byte_size)) : 1;
    
    $dir = ($len < $byte_size) ? 1 : 0;
    if ($dir) {
	$w = $len;
	$h = $bytes * $byte_size;
    } else {
	$w = $bytes * $byte_size;
	$h = $len;
    }
    #print "w: $w h: $h dir $dir\n";
    
    init_bitmatrix($w, $h);
    load_bitmatrix();
    redraw_settings(); 
    redraw_editor(); 
    redraw_result();
}

# Resize editor (zeroize matrix)

sub resize
{
    my ($widget, $data) = @_;

    init_bitmatrix($w, $h);
    init_matrix($w, $h);
    redraw_editor(); 
    redraw_result();
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
    $frame->set_border_width(3);
    my $table = Gtk2::Table->new($rows+1, $cols+1, FALSE);
    $table->set_border_width(8);

    for (my $x = 0; $x < $cols; $x++) {
	my $x_lab = ($dir) ? $x : $w - $x-1;
	my $x_hex = '0x' . dec2hex($x_lab, 2);
        $label = Gtk2::Label->new($x_hex);
	$label->modify_font($font);
        $label->set_angle(90);
        $label->set_alignment(0.5, 0);
	$table->attach_defaults($label, $x, $x+1, 0, 1);
    }

    for (my $y = 0; $y < $rows; $y++) {
	for (my $x = 0; $x < $cols; $x++) {
	    $togglebutton = Gtk2::ToggleButton->new(' ');
	    $table->attach_defaults($togglebutton, $x, $x+1, $y+1, $y+2);
	    $togglebutton->set_active(TRUE) if ($bitmatrix[$y][$x]);
	    $togglebutton->set_label('*')  if ($bitmatrix[$y][$x]);
	    $togglebutton->signal_connect('toggled'=>\&callback, [$x, $y]);
	}
	my $y_lab = ($dir) ? $h - $y-1 : $y;
	my $y_hex = '0x' . dec2hex($y_lab, 2);
	$label = Gtk2::Label->new($y_hex);
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
    $frame->set_border_width(3);
    my $len = ($dir) ? $cols : $rows;
    my $bytes = bytes($cols, $rows);
    my $table = Gtk2::Table->new($len+1, 1, FALSE);
    $table->set_border_width(8);
    $label = Gtk2::Label->new();
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
    $frame->set_border_width(3);

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

    my $buttonc = Gtk2::Button->new('Clear editor');
    $buttonc->signal_connect('clicked'=>\&clear);

    my $labd = Gtk2::Label->new('Byte/word direction:');
    $labd->modify_font($font);
    my $combod = Gtk2::ComboBox->new_text;
    $combod->append_text('horizontal');
    $combod->append_text('vertical');
    $combod->set_active(0);
    $combod->signal_connect('changed'=>\&switch);

    my $vboxd = Gtk2::VBox->new(FALSE,5);
    $vboxd->add($labd);
    $vboxd->add($combod);

    my $vboxs = Gtk2::VBox->new(FALSE,5);
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

# Main window definition

$window = Gtk2::Window->new('toplevel');
$window->set_title("Font and bitmap editor");
$window->signal_connect(delete_event => \&delete_event);
$window->set_border_width(10);
$window->set_resizable(FALSE);

# Load from file frame

my $filechooser = Gtk2::FileChooserButton->new ('Select a file' , 'open');
my $filter = Gtk2::FileFilter->new();
foreach (@c_files) { $filter->add_pattern($_); }
$filechooser->set_filter($filter);

my $framef = Gtk2::Frame->new('Load from file');
$framef->set_border_width(3);
my $combof1 = Gtk2::ComboBox->new_text;
my $combof2 = Gtk2::ComboBox->new_text;
my $hboxf = Gtk2::HBox->new(FALSE,5);
$filechooser->signal_connect('selection-changed'=>\&copen,[$combof1,$combof2]);
$combof1->signal_connect('changed'=>\&cload1,[$combof1,$combof2]);
$combof2->signal_connect('changed'=>\&cload2,[$combof1,$combof2]);
$hboxf->add($filechooser);
$hboxf->add($combof1);
$hboxf->add($combof2);
$framef->add($hboxf);

# Show layout of main window, init editor and Gtk main

init_bitmatrix($w, $h);
init_matrix($w, $h);

$settings = draw_settings($w, $h);
$editor = draw_editor($w, $h);
$result = draw_result($w, $h);

$hbox = Gtk2::HBox->new(FALSE,5);
$hbox->add($settings);
$hbox->add($editor);
$hbox->add($result);

sub create_buffer {
    my $buffer = Gtk2::TextBuffer->new();
    my $iter = $buffer->get_start_iter;
    $buffer->insert_with_tags_by_name ($iter, "ciao\nciao\ntest\ntext\n");
    return $buffer;
}

my $buffer = &create_buffer;
my $tview = Gtk2::TextView->new_with_buffer($buffer);
$tview->set_editable(FALSE);
#$hbox->add($tview);

$vbox = Gtk2::VBox->new(FALSE,5);
$vbox->add($framef);
$vbox->add($hbox);

$window->add($vbox);
$window->show_all;

Gtk2->main;

0;
