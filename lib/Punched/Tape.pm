package Punched::Tape;
#ABSTRACT: Punched tape emulator

use 5.12.0; # new perl for old media :-)
use Carp;

# TODO: use Bit::Vector

use Scalar::Util qw(looks_like_number);

=head1 DESCRIPTION

This module is about this little dotted paper strips that were used for
confetti production. I have never worked with punched tape before and my
primary application is a music box, so the design of this module may be a bit
strange for those of you still working with punched tape, day by day.
The module is not limited to one particular type of punched tape, such as
ECMA-10 (1965), or to one specific encoding, such as Baudot code.

A punched tape is a sequence of I<characters>, each consisting of the same
number of I<bits>.  The bits are also numbered as I<channels> or C<tracks>
for the whole tape. The following diagrams shows a punched tape with eight
characters of three bits:

    +-----------------+
    | * * * *         | <- 3rd channel/track
    | * *     * *     | <- 2nd channel/track
    | *   *   *   *   | <- 1st channel/track
    +-----------------+
      ^             ^
      |             |
    1st character  8th character

The perlish way this module starts counting characters and channels from zero.
By the way, diagrams as above can be created withe the C</show> method. For
better graphics use L<Punched::Tape::Draw>.

=head1 SYNOPSIS

    use Punched::Tape;

    # five channel (Honeywell 400 (1964))
    my $tape = Punched::Tape->new( bits => 5 );

    $tape->punch("x  xx");   # same as "x xx "
	$tape->get(0);           # returns "*  ** "
    $tape->punch(" * * *");  # next
    $tape->back;             # rewind one step
    $tape->punch(" x");      # overpunch
   
    ...

	print $tape->show( frame => 1 );

=cut

our %fields = (
	bits   => 5,
	length => undef,
	pos    => 0,
);

no strict 'refs';
foreach my $field ( keys %fields ) {
    *{"Punched::Tape::$field"} = sub {
		return $_[0]->{ $field } if scalar( @_ ) == 1;
		return $_[0]->{ $field } = $_[1] // $fields{ $field };
	};
}

=method new ( %options ) 

Creates a new, empty tape of unlimited length. You can specify the number of
C<bits>, a C<length>, and a starting position (C<pos>).

=cut

sub new {
    my ($class, %options) = @_; 
	my $self = bless { }, (ref $class || $class);
	foreach (keys %fields) {
		$self->{$_} = $options{$_} // $fields{$_};
	}
	$self->{data} = [ ];
   	$self;
}

=method get ( [ $position ] [ %options ] )

Get a character at the current or a specific position.
By default it is returned as string with C<*> for holes.

=cut

sub get {
	my $self = shift;
	my ($pos, %options) = @_ % 2 ? @_ : ($self->pos, @_);

	croak "position out of tape"
		if defined $self->length and $pos >= $self->length;

	$options{0} //= ' ';
	$options{1} //= '*';

    return join( '', map { $options{$_} } @{
		$self->{data}->[$pos] // [ map {0} 1..$self->{bits} ]
	} );
}

=method next ( [ $position ] [ %options ] )

Get a character at the current position and increment the position.
Same options as the 'get' method.

=cut

sub next {
	my $self = shift;
	
	my $char = $self->get( @_ );
	$self->rewind(-1);

	return $char;
}

=method punch ( $data )

Extends the paper. The C<data> must be a string.

=cut

sub punch {
    my $self = shift;
    my $data = shift;

    $data = [ split '', $data ];

    my $nope = qr{[0 _-]};

    my @add = map { ($data->[$_] // '0') =~ $nope ? 0 : 1 } (0 .. $self->{bits}-1);
    if ( $self->{data}->[ $self->{pos} ] ) {
        foreach my $p ( 0 .. $self->{bits} ) {
            $self->{data}->[ $self->{pos} ]->[$p] = 1
                if $add[$p];
        }
    } else {
        $self->{data}->[ $self->{pos} ] = [ @add ];
    }

    $self->rewind(-1);
}

=method rewind ( [ $steps ] )

Rewind the position or set back to the start.

=cut

sub rewind {
    my $self = shift;
	# TODO: start / end
    return $self->{pos} = @_ ? $self->{pos} - shift : 0;
}

=method back

Rewind one step.

=cut

sub back {
    shift->rewind(1);
}

=method show ( %options )

Returns an ASCII representation.

=cut

sub show {
    my ($self, %opt) = @_;

    $opt{orientation} //= 'horizontal';

	my $has_start = not defined $opt{from};
	my $has_end = defined $self->{length} && not defined $opt{to};

	my $from = $opt{from} // 0;
	my $to = $opt{to} // $self->length ? $self->length - 1 : $self->pos;

    $opt{1}    //= '*';
    $opt{0}    //= ' ';

    $opt{wide}  //= 0;

    my @tracks;

    if ( $opt{orientation} eq 'horizontal' ) {
		my $f;
		if ( $opt{frame} ) {
			my $l = $to - $from + 1;
			my $w = $l + ($l-1) * $opt{wide};
			$f = ($has_start ? '+-' : '') 
			   . ('-' x $w) 
			   . ($has_end ? '-+' : ''); 
			push @tracks, $f;
		}
        foreach my $track ( 0 .. $self->{bits}-1 ) {
			my $t = $self->track( $track, %opt );
            push @tracks, $t;
        }
		push @tracks, $f if $f;
    } else {
		# TODO: support frame
        foreach my $row ( $from .. $to ) {
            push @tracks, join( '', 
                map { $opt{$_} }
                @{$self->{data}->[$row]}
            );
           }
    }

    return join("\n", @tracks, "");
}

=method track ( $track, %options )

Returns a selected track in diagram format. Supported options are C<from>,
C<to>, C<0>, C<1>, and C<wide> as described in method L</show>.

=cut

sub track {
    my ($self, $track, %opt) = @_;

	my $has_start = not defined $opt{from};
	my $has_end = defined $self->{length} && not defined $opt{to};

    $opt{from} //= 0;
    $opt{to}   //= $self->length ? $self->length - 1 : $self->pos;
    $opt{1}    //= '*';
    $opt{0}    //= ' ';

	my $t = '';

	$t = join( $opt{wide} ? ' ' : '',
        map { $opt{ $self->{data}->[$_]->[$track] } }
        ( $opt{from} .. $opt{to} )
    ) if $opt{from} < $opt{to};

	if ($opt{frame}) {
		$t .= " |"  if $has_end;
		$t = "| $t" if $has_start;
	}

    return $t;
}

1;

=head1 NOTES

The module requires Perl 5.12 because I am tired of writing CPAN modules for
ancient versions of Perl -- instead I wrote a module for an anchient storage
medium.

=head1 SEE ALSO

L<http://www.kloth.net/services/ttypunch.php>,
L<http://www.diycalculator.com/sp-paper.shtml> etc.

=cut
