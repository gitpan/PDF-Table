package PDF::Table;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.03';


############################################################
#
# new - Constructor
#
# Parameters are meta information about the PDF
#
# $pdf = PDF::Table->new();
#
############################################################

sub new

	{
	my ($proto) = @_;

	my $class = ref($proto) || $proto;
	my $self = {};
	bless ($self, $class);
	return $self;
	}

############################################################
#
# text_block - utility method to build multi-paragraph blocks of text
#
# ($width_of_last_line, $ypos_of_last_line, $left_over_text) = text_block(
#   $text_handler_from_page,
#    $text_to_place,
#    -x        => $left_edge_of_block,
#    -y        => $baseline_of_first_line,
#    -w        => $width_of_block,
#    -h        => $height_of_block,
#   [-lead     => $font_size * 1.2 | $distance_between_lines,]
#   [-parspace => 0 | $extra_distance_between_paragraphs,]
#   [-align    => "left|right|center|justify|fulljustify",]
#   [-hang     => $optional_hanging_indent,]
#);
#
############################################################

sub text_block
	{
	    my $self = shift;
	    my $text_object = shift;
	    my $text = shift;
	    my %arg = @_;

	    my($align,$ypos,$xpos,$line_width,$wordspace, $endw) = (undef,undef,undef,undef,undef,undef);
	    my @line = ();
	    my %width = ();
	    # Get the text in paragraphs
	    my @paragraphs = split(/\n/, $text);

		$arg{'-lead'} ||= 14;
	    # calculate width of all words
	    my $space_width = $text_object->advancewidth("\x20");
	    my @words = split(/\s+/, $text);
	    foreach (@words) {
		next if exists $width{$_};
		$width{$_} = $text_object->advancewidth($_);
	    }

	    $ypos = $arg{'-y'};
	    my @paragraph = split(/ /, shift(@paragraphs));
	    my $first_line = 1;
	    my $first_paragraph = 1;

	    # while we can add another line
	    while ( $ypos >= $arg{'-y'} - $arg{'-h'} + $arg{'-lead'} ) {

		unless (@paragraph) {
		    last unless scalar @paragraphs;
		    @paragraph = split(/ /, shift(@paragraphs));

		    $ypos -= $arg{'-parspace'} if $arg{'-parspace'};
		    last unless $ypos >= $arg{'-y'} - $arg{'-h'};
		    $first_line = 1;
		    $first_paragraph = 0;
		}

		$xpos = $arg{'-x'};

		# while there's room on the line, add another word
		@line = ();

		$line_width =0;
		if ($first_line && exists $arg{'-hang'}) {
		    my $hang_width = $text_object->advancewidth($arg{'-hang'});

		    $text_object->translate( $xpos, $ypos );
		    $text_object->text( $arg{'-hang'} );

		    $xpos         += $hang_width;
		    $line_width   += $hang_width;
		    $arg{'-indent'} += $hang_width if $first_paragraph;
		}
		elsif ($first_line && exists $arg{'-flindent'}) {
		    $xpos += $arg{'-flindent'};
		    $line_width += $arg{'-flindent'};
		}
		elsif ($first_paragraph && exists $arg{'-fpindent'}) {
		    $xpos += $arg{'-fpindent'};
		    $line_width += $arg{'-fpindent'};
		}
		elsif (exists $arg{'-indent'}) {
		    $xpos += $arg{'-indent'};
		    $line_width += $arg{'-indent'};
		}


		while ( @paragraph and $text_object->advancewidth(join("\x20", @line)."\x20".$paragraph[0])+$line_width < $arg{'-w'} ) {
		    #$line_width += $width{ $paragraph[0] };
		    push(@line, shift(@paragraph));
		}
		$line_width += $text_object->advancewidth(join('', @line));
		#while ( @paragraph and ($line_width + (scalar(@line) * $space_width) + $width{$paragraph[0]}) < $arg{'-w'} ) {
		#    $line_width += $width{ $paragraph[0] };
		#    push(@line, shift(@paragraph));
		#}

		# calculate the space width
		if ($arg{'-align'} eq 'fulljustify' or ($arg{'-align'} eq 'justify' and @paragraph)) {
		    if (scalar(@line) == 1) {
			@line = split(//,$line[0]);
		    }
		    $wordspace = ($arg{'-w'} - $line_width) / (scalar(@line) - 1);
		    $align='justify';
		} else {
		    $align=($arg{'-align'} eq 'justify') ? 'left' : $arg{'-align'};
		    $wordspace = $space_width;
		}
		$line_width += $wordspace * (scalar(@line) - 1);


		if ($align eq 'justify') {
		    foreach my $word (@line) {
			$text_object->translate( $xpos, $ypos );
			$text_object->text( $word );
			$xpos += ($width{$word} + $wordspace) if (@line);
		    }
		    $endw = $arg{'-w'};
		} else {

		    # calculate the left hand position of the line
		    if ($align eq 'right') {
			$xpos += $arg{'-w'} - $line_width;
		    } elsif ($align eq 'center') {
			$xpos += ($arg{'-w'}/2) - ($line_width / 2);
		    }

		    # render the line
		    $text_object->translate( $xpos, $ypos );
		    $endw = $text_object->text( join("\x20", @line));
		}
		$ypos -= $arg{'-lead'};
		$first_line = 0;
	    }
	    unshift(@paragraphs, join(' ',@paragraph)) if scalar(@paragraph);
	    return ($endw, $ypos, join("\n", @paragraphs))
	}


############################################################
#
# table - utility method to build multi-row, multicolumn tables
#
# ($page,$pg_cnt,$cur_y) = table(
#   $pdf_object,
#   $page_object_to_start_on,
#    $table_data, # an arrayref of arrayrefs
#    -x        	=> $left_edge_of_table,
#    -start_y   => $baseline_of_first_line_on_first_page,
#    -next_y   => $baseline_of_first_line_on_succeeding_pages,
#    -start_h   => $baseline_of_first_line_on_first_page,
#    -next_h   => $baseline_of_first_line_on_succeeding_pages,
#   [-w        	=> $table_width,] # technically optional, but almost always a good idea to use
#   [-row_height    	=> $min_row_height,] # minimum height of row
#   [-padding    	=> $cellpadding,] # default 0,
#   [-padding_left    	=> $leftpadding,] # overides -padding
#   [-padding_right    	=> $rightpadding,] # overides -padding
#   [-padding_top    	=> $toppadding,] # overides -padding
#   [-padding_bottom    => $bottompadding,] # overides -padding
#   [-border     => $border width,] # default 1, use 0 for no border
#   [-border_color     => $border_color,] # default black
#   [-font    => $pdf->corefont,] # default $pdf->corefont('Times',-encode => 'latin1')
#   [-font_size    => $font_sizwe,] # default 12
#   [-font_color    => font_color,] # font color
#   [-font_color_odd    => font_color_odd,] # font color for odd rows
#   [-font_color_even    => font_color_odd,] # font color for odd rows
#   [-background_color	=> 'gray',] # cell background color
#   [-background_color_odd	=> $background_color_odd,] # cell background color for odd rows
#   [-background_color_even	=> $background_color_even,] # cell background color for even rows
# 	[-column_props    => [
#		{width => $col_a_width, # width of column
#		justify => 'left'|'right', # text justify in cell
#		font => $pdf->corefont, # font for this column
#		font_size => $col_a_font_size, # font size for this column
#		font_color => $col_a_font_color, # font color for this column
#		background_color => $col_a_background_color # background color for this column
#		},
#		...
#		]
#	]
#	# column_props is an arrayref of hashrefs, where each hashref sets properties for a column in the table.
#	# -All keys in the hashref are optional, with one caveat in the case of 'width'. See below.
#	# -If used, there should be one hashref for each column, even if it is an empty hashref
#	# -Column_props take precendence over general or odd/even row properties
#	# -If using the 'width' property, it is required for all columns and the total of all column widths should
#	#  be equal to the -w parameter (overall table width). In other words, if you are going to set individual column widths,
#	#  set them accurately with respect to overall table width, otherwise behavior will be unpredictable.
#	#  This is a current limitation, not a feature :-)
#);
#
############################################################
sub table
	{
	my $self = shift;
	my $pdf = shift;
	my $page = shift;
	my $data = shift;
	my %arg = @_;
	my $txt = $page->text;
	# set default properties
	my $fnt_name = $arg{'-font'} || $pdf->corefont('Times',-encode => 'latin1');
	my $fnt_size = $arg{'-font_size'} || 12;
	$txt->font($fnt_name,$fnt_size);

	my $lead = $arg{'-lead'} || $fnt_size;
	my $pad_left = $arg{'-padding_left'} || $arg{'-padding'} || 0;
	my $pad_right = $arg{'-padding_right'} || $arg{'-padding'} || 0;
	my $pad_top = $arg{'-padding_top'} || $arg{'-padding'} || 0;
	my $pad_bot = $arg{'-padding_bottom'} || $arg{'-padding'} || 0;
	my $pad_w = $pad_left+$pad_right;
	my $pad_h = $pad_top+$pad_bot;
	my $line_w = defined $arg{'-border'}? $arg{'-border'}:1;
	my $background_color_even = $arg{'-background_color_even'} || $arg{'-background_color'} || undef;
	my $background_color_odd = $arg{'-background_color_odd'} || $arg{'-background_color'} || undef;
	my $font_color_even = $arg{'-font_color_even'} || $arg{'-font_color'} || 'black';
	my $font_color_odd = $arg{'-font_color_odd'} || $arg{'-font_color'} || 'black';
	my $min_row_h = defined ($arg{'-row_height'}) && ($arg{'-row_height'} > ($fnt_size + $pad_top + $pad_bot))? $arg{'-row_height'}:$fnt_size + $pad_top + $pad_bot;
	my $row_h = $min_row_h;
	my $pg_cnt = 1;
	my $cur_y = $arg{'-start_y'};
	if(ref $data){

		# determine column widths based on content
		my $col_props =  $arg{'-column_props'} || []; # a arrayref whose values are a hashref holding the minimum and maximum width of that column
		my $row_props = []; # an array ref of arrayrefs whose values are the actual widths of the column/row intersection
		my ($total_max_w,$total_min_w) = (0,0); # scalars that hold sum of the maximum and minimum widths of all columns
		my ($max_col_w,$min_col_w) = (0,0);
		my $word_w = {};
		my ($row,$col_name,$col_fnt_size,$space_w);
		my $rcnt = 0;
		foreach $row (@$data){
			my $foo = []; #holds the widths of each column
			for(my $j =0;$j < scalar(@$row);$j++){

				# look for font information for this column
				$col_fnt_size = $col_props->[$j]->{'font_size'}? $col_props->[$j]->{'font_size'}:$fnt_size;
				if($col_props->[$j]->{'font'}){
					$txt->font($col_props->[$j]->{'font'},$col_fnt_size);
				}
				else{
					$txt->font($fnt_name,$col_fnt_size);
				}
				$space_w = $txt->advancewidth("\x20");

				$foo->[$j] = 0;
				$max_col_w = 0;
				$min_col_w = 0;
				my @words = split(/\s+/, $row->[$j]);
				foreach (@words) {
					if(!exists $word_w->{$_}){
						$word_w->{$_} = $txt->advancewidth($_) + $space_w;
					};
					$foo->[$j] += $word_w->{$_};
					$min_col_w = $word_w->{$_} if $word_w->{$_} > $min_col_w;
					$max_col_w += $word_w->{$_};
				}
				$min_col_w += $pad_w;
				$max_col_w += $pad_w;
				$foo->[$j] += $pad_w;
				# keep a running total of the overall min and max widths
				$col_props->[$j]->{min_w} = $col_props->[$j]->{min_w} || 0;
				$col_props->[$j]->{max_w} = $col_props->[$j]->{max_w} || 0;
				if($min_col_w > $col_props->[$j]->{min_w}){
					$total_min_w -= $col_props->[$j]->{min_w};
					$total_min_w += $min_col_w;
					$col_props->[$j]->{min_w} = $min_col_w ;
				}
				if($max_col_w > $col_props->[$j]->{max_w}){
					$total_max_w -= $col_props->[$j]->{max_w};
					$total_max_w += $max_col_w;
					$col_props->[$j]->{max_w} = $max_col_w ;
				}
			}
			$row_props->[$rcnt] = $foo;
			$rcnt++;
		}
		# calc real column widths width
		my ($col_widths,$width) = $self->col_widths($col_props, $total_max_w, $total_min_w, $arg{'-w'});
		$width = $arg{'-w'} if $arg{'-w'};
		my $border_color = $arg{-border_color} || 'black';
		#my $line_w = 1;

		my $comp_cnt = 1;
		my ($gfx,$gfx_bg,$background_color,$font_color);
		my ($bot_marg, $table_top_y, $text_start, $record,$record_widths);
		$rcnt=0;
		# Each iteration adds a new page as neccessary
		while(scalar(@{$data})){
			if($pg_cnt == 1){
				$table_top_y = $arg{'-start_y'};
				$bot_marg = $table_top_y - $arg{'-start_h'};
			}
			else{
				$page = $pdf->page;
				$table_top_y = $arg{'-next_y'};
				$bot_marg = $table_top_y - $arg{'-next_h'};
			}

			$gfx_bg = $page->gfx;
			$txt = $page->text;
			$txt->font($fnt_name, $fnt_size);
			$gfx = $page->gfx;
			$gfx->strokecolor($border_color);
			$gfx->linewidth($line_w);

			#draw the top line
			$cur_y = $table_top_y;
			$gfx->move( $arg{'-x'},$cur_y);
			$gfx->hline($arg{'-x'}+$width);


			my $safety2 = 20;
			# Each iteration adds a row to the current page until the page is full or there are no more rows to add
			while(scalar(@{$data}) and $cur_y-$row_h > $bot_marg){
				#remove the next item from $data
				$record = shift @{$data};
				$record_widths = shift @$row_props;
				next unless $record;

				# choose colors for this row
				$background_color = $rcnt%2?$background_color_even:$background_color_odd;
				$font_color = $rcnt%2?$font_color_even:$font_color_odd;
				#$txt->fillcolor($font_color);

				$text_start = $cur_y-$fnt_size-$pad_top;
				my $cur_x = $arg{'-x'};
				my $leftovers = undef;
				my $do_leftovers = 0;
				for(my $j =0;$j < scalar(@$record);$j++){
					next unless $col_props->[$j]->{max_w};
					$leftovers->[$j] = undef;

					# look for column properties that overide row properties
					if($col_props->[$j]->{'font_color'}){
						$txt->fillcolor($col_props->[$j]->{'font_color'});
					}
					else{
						$txt->fillcolor($font_color);
					}
					$col_fnt_size = $col_props->[$j]->{'font_size'}? $col_props->[$j]->{'font_size'}:$fnt_size;
					if($col_props->[$j]->{'font'}){
						$txt->font($col_props->[$j]->{'font'},$col_fnt_size);
					}
					else{
						$txt->font($fnt_name,$col_fnt_size);
					}
					$col_props->[$j]->{justify} = $col_props->[$j]->{justify} || 'left';
					# if the contents is wider than the specified width, we need to add the text as a text block
					if($record_widths->[$j] and ($record_widths->[$j] > $col_widths->[$j])){
						my($width_of_last_line, $ypos_of_last_line, $left_over_text) = $self->text_block(
						   	$txt,
						    $record->[$j],
						    -x        => $cur_x+$pad_left,
						    -y        => $text_start,
						    -w        => $col_widths->[$j] - $pad_w,
							-h		  => $cur_y - $bot_marg - $pad_top - $pad_bot,
							-align    => $col_props->[$j]->{justify},
							-lead	  => $lead
						);
						#$lead is added here because $self->text_block returns the incorrect yposition - it is off by $lead
						my $this_row_h = $cur_y - ($ypos_of_last_line +$lead-$pad_bot);
						$row_h = $this_row_h if $this_row_h > $row_h;
						if($left_over_text){
							$leftovers->[$j] = $left_over_text;
							$do_leftovers =1;
						}
					}
					# Otherwise just use the $page->text() method
					else{
						my $space = $pad_left;
						if($col_props->[$j]->{justify} eq 'right'){
							$space = $col_widths->[$j] - ($txt->advancewidth($record->[$j]) + $pad_right);
						}
						$txt->translate($cur_x+$space,$text_start);
						$txt->text($record->[$j]);
					}

					$cur_x += $col_widths->[$j];
				}
				if($do_leftovers){
					unshift @$data, $leftovers;
					unshift @$row_props, $record_widths;
					$rcnt--;
				}

				# draw cell bgcolor
				# this has to be separately from the text loop because we do not know the finel height of the cell until all text has been drawn
				if($background_color){
					$cur_x = $arg{'-x'};
					for(my $j =0;$j < scalar(@$record);$j++){
						$gfx_bg->rect( $cur_x, $cur_y-$row_h, $col_widths->[$j], $row_h);
						if($col_props->[$j]->{'background_color'}){
							$gfx_bg->fillcolor($col_props->[$j]->{'background_color'});
						}
						else{
							$gfx_bg->fillcolor($background_color);
						}

						$gfx_bg->fill();
						$cur_x += $col_widths->[$j];
					}
				}

				$cur_y -= $row_h;
				$row_h = $min_row_h;
				$gfx->move($arg{'-x'},$cur_y);
				$gfx->hline($arg{'-x'}+$width);
				$rcnt++;
			}
			# draw vertical lines
			$gfx->move($arg{'-x'},$table_top_y);
			$gfx->vline($cur_y);
			my $cur_x = $arg{'-x'};
			for(my $j =0;$j < scalar(@$record);$j++){
				$cur_x += $col_widths->[$j];
				$gfx->move( $cur_x,$table_top_y);
				$gfx->vline($cur_y);

			}
			# ACTUALLY draw all the lines
			$gfx->fillcolor($border_color);
			$gfx->stroke if $line_w;
			$pg_cnt++;
		}
	}

	return ($page,--$pg_cnt,$cur_y);
	}


# calculate the column widths
sub col_widths{
	my $self = shift;
	my $col_props = shift;
	my $max_width = shift;
	my $min_width = shift;
	my $avail_width = shift;


	my$calc_widths;
	my $colname;
	my $total = 0;
	for(my $j =0;$j < scalar(@$col_props);$j++){
	#foreach $colname (keys %$col_props){

		# if the width is specified, use that
		if( $col_props->[$j]->{width}){
			$calc_widths->[$j] = $col_props->[$j]->{width};
		}
		# if no avail_width is specified
		# or there is no max_w for the column specified, use the max width
		elsif( !$avail_width || !$col_props->[$j]->{max_w}){
			$calc_widths->[$j] = 	$col_props->[$j]->{max_w};
		}
		# if the available space is more than the max, grow each column proportionally
		elsif($avail_width > $max_width and $max_width > 0){
			$calc_widths->[$j] = 	$col_props->[$j]->{max_w} * ($avail_width/$max_width);
		}
		# if the min width is greater than the available width, return the min width
		elsif($min_width > $avail_width){
			$calc_widths->[$j] = 	$col_props->[$j]->{min_w};
		}
		# else use the autolayout algorithm from RFC 1942
		else{
			$calc_widths->[$j] = $col_props->[$j]->{min_w}+(($col_props->[$j]->{max_w} - $col_props->[$j]->{min_w}) * ($avail_width -$min_width))/ ($max_width -$min_width);
		}
		$total += $calc_widths->[$j];
	}
	return ($calc_widths,$total);
	}
1;

__END__

=pod

=head1 NAME

PDF::Table - A utility class for building table layouts in a PDF::API2 object.

=head1 SYNOPSIS

 use PDF::API2;
 use PDF::Table;

 my $pdftable = new PDF::Table;
 my $pdf = new PDF::API2(-file => "table_of_lorem.pdf");
 my $page = $pdf->page;

 # some data to layout
 my $some_data =[
	["1 Lorem ipsum dolor",
	"Donec odio neque, faucibus vel",
	"consequat quis, tincidunt vel, felis."],
	["Nulla euismod sem eget neque.",
	"Donec odio neque",
	"Sed eu velit."],
	... and so on
 ];

 # build the table layout
 $pdftable->table(
	 # required params
	 $pdf,
	 $page,
	 $some_data,
	 -x  => $left_edge_of_table,
	 -start_y => 500,
	 -next_y => 700,
	 -start_h => 300,
	 -next_h => 500,
	 # some optional params
	 -w => 570,
	 -padding => 5,
	 -padding_right => 10,
	 -background_color_odd => "gray",
	 -background_color_even => "lightblue", #cell background color for even rows
  );

 # do other stuff with $pdf
...


=head1 DESCRIPTION

This class is a utility for use with the PDF::API2 module from CPAN. It can be used to display text data in a table layout within the PDF. The text data must be in a 2d array (such as returned by a DBI statement handle fetchall_arrayref() call). The PDF::Table will automatically add as many new pages as necessary to display all of the data. Various layout properties, such as font, font size, and cell padding and background color can be specified for each column and/or for even/odd rows. See the METHODS section.

=head1  METHODS

=head2 new

=over

Returns an instance of the class. There are no parameters.

=back

=head2 table($pdf, $page_obj, $data, %opts)

=over

 The main method of this class. Takes a PDF::API2 instance, a page instance, some data to build the table and formatting options. The formatting options should be passed as named parameters. This method will add more pages to the pdf instance as required based on the formatting options and the amount of data.

=back

=over

 The return value is a 3 item list where the first item is the PDF::API2::Page instance that the table ends on, the second item is the count of pages that the table spans, and the third item is the y position of the table bottom.

=back

=over

=item Example:

 ($end_page,$pages_spanned, $table_bot_y) = $pdftable->table(
	 $pdf, # A PDF::API2 instance
	 $page_to_start_on,  # A PDF::API2::Page instance that the table will start on. Should be a child of the $pdf instance
	 $data, # 2D arrayref of text strings
	 -x  => $left_edge_of_table,
	 -start_y   => $baseline_of_first_line_on_first_page,
	 -next_y   => $baseline_of_first_line_on_succeeding_pages,
	 -start_h   => $height_on_first_page,
	 -next_h => $height_on_succeeding_pages,
	 [-w  => 570,] # width of table. technically optional, but almost always a good idea to use
	 [-padding => "5",] # cell padding
	 [-padding_top => "10",] #top cell padding, overides -pad
	 [-padding_right  => "10",] #right cell padding, overides -pad
	 [-padding_left  => "10",] #left padding padding, overides -pad
	 [-padding_bottom  => "10",] #bottom padding, overides -pad
	 [-border  => 1,] # border width, default 1, use 0 for no border
	 [-border_color => "red",] # default black
	 [-font  => $pdf->corefont("Helvetica", -encoding => "latin1"),] # default font
	 [-font_size => 12,]
	 [-font_color_odd => "purple",]
	 [-font_color_even => "black",]
	 [-background_color_odd	=> "gray",] #cell background color for odd rows
	 [-background_color_even => "lightblue",] #cell background color for even rows
	 [-column_props => $col_props] # see below
 )

=back

=over

 If the -column_props parameter is used, it should be an arrayref of hashrefs, with one hashref for each column of the table. Each hashref can contain any of keys shown here:

=back

=over

  $col_props = [
	{
		width => 100,
		justify => "[left|right|center]",
		font => $pdf->corefont("Times", -encoding => "latin1"),
		font_size => 10
		font_color=> "red"
		background_color => "yellow",
	},
	# etc.
  ];

=back

=over

 If the "width" parameter is used for -col_props, it should be specified for every column and the sum of these should be exactly equal to the -w parameter, otherwise Bad Things may happen. In cases of a conflict between column formatting and odd/even row formatting, the former will override the latter.


=head2 text_block($txtobj,$string,-x => $x, -y => $y, -w => $width, -h => $height)

=over

Utility method to create a block of text. The block may contain multiple paragraphs.

=back

=over

=item Example:

=back

=over

 # PDF::API2 objects
 my $page = $pdf->page;
 my $txt = $page->text;

=back

=over

 ($width_of_last_line, $ypos_of_last_line, $left_over_text) = $pdftable->text_block(
    $txt,
    $text_to_place,
    -x        => $left_edge_of_block,
    -y        => $baseline_of_first_line,
    -w        => $width_of_block,
    -h        => $height_of_block,
   [-lead     => $font_size * 1.2 | $distance_between_lines,]
   [-parspace => 0 | $extra_distance_between_paragraphs,]
   [-align    => "left|right|center|justify|fulljustify",]
   [-hang     => $optional_hanging_indent,]
 );


=back

=head1 AUTHOR

Daemmon Hughes

=head1 VERSION

0.03

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Daemmon Hughes, portions Copyright 2004 Stone
Environmental Inc. (www.stone-env.com) All Rights Reserved.
Bug fix by Desislav Kamenov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=head1 PLUGS

Much of the work on this module was sponsered by
Stone Environmental Inc. (www.stone-env.com).

The text_block() method is a slightly modified copy of the one from
Rick Measham's PDF::API2 tutorial at
http://pdfapi2.sourceforge.net/cgi-bin/view/Main/YourFirstDocument

Comming Soon new extended version.
=head1 SEE ALSO

L<PDF::API2>

=cut

