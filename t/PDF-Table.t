# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl PDF-Table.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;
BEGIN { use_ok('PDF::Table') };

use_ok('PDF::API2');
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $pdftable = new PDF::Table;

$filename = 'PDFTable'.time;
my $pdf = new PDF::API2(-file => $filename);
my $some_data =[
	['1 Lorem ipsum d',
	'Donec odio neque',
	'consequat quis, tincidunt'],
];

my $page_to_start_on = $pdf->page;
$page_to_start_on->mediabox(612,792);

my ($final_page,$pages_added_cnt,$cur_y) = $pdftable->table(
	#required params
   $pdf,
   $page_to_start_on,
   $some_data,
   -x        	=> 20,
   -start_y   => 500,
   -next_y   => 500,
   -start_h   => 200,
   -next_h   => 200,
   );
   
$pdf->save();
$pdf->end();

ok( -e $filename, 'test pdf created');
unlink $filename;


