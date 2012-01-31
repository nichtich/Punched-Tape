use strict;
use Test::More;
use Punched::Tape;

my $t = Punched::Tape->new( bits => 3 );
is $t->pos, 0, 'new tape';
is $t->get, '   ', 'empty char';

$t->punch("x0x");
is $t->get(0), '* *', 'punched char';
is $t->pos, 1, 'new position';
is $t->get, '   ', 'empty char';
$t->back;
is $t->get, '* *', 'punched char';
is $t->get( 0 => '_', 1 => '+' ), '+_+', 'custom format';

$t->pos(1);
$t->punch('_*_');
is $t->get(1), ' * ', 'punched char' ;

$t->rewind(1);
is $t->pos, 1, 'rewind';
$t->rewind;
is $t->pos, 0, 'rewinded';
is $t->next, '* *', 'next';
is $t->pos, 1, 'next';

is $t->track(0), '* ', '1st track';
is $t->track(1), ' *', '2nd track';
is $t->track(2), '* ', '3rd track';

$t->next;
$t->punch('  *');
$t->back;
is $t->track(2, 0 => '-', wide => 1), '* - *', 'wide track';
  
is $t->show, "*  \n * \n* *\n", 'horizontal ascii tape';

is $t->show( wide => 1, frame => 1 ), <<TAPE, 'ascii tape';
+------
| *    
|   *  
| *   *
+------
TAPE

$t->length(3);
is $t->length, 3, 'set length';
is $t->show( from => 1, frame => 1, 1 => 'X' ), <<TAPE, 'ascii tape';
---+
   |
X  |
 X |
---+
TAPE

my $empty = Punched::Tape->new(bits => 2);
is $empty->show( wide => 2 ), "\n\n", "empty";
is $empty->show( frame => 1 ), "+--\n| \n| \n+--\n", "empty";

done_testing;
