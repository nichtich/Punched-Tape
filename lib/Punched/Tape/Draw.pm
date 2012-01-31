package Punched::Tape::Draw;
#ABSTRACT: Draw nice images of Punched Tapes

use 5.12.0;
use Punched::Tape;
use Cairo;

use base 'Exporter';
our @EXPORT = qw(draw_tape);

use constant { M_PI => 4 * atan2(1, 1) };

=head1 SYNOPSIS

    # eight channel (Honeywell 400, 1964)
    # see http://www.computermuseum.li/Testpage/PaperTapeDiagram.htm
    $tape = Punched::Tape->new( bits => 8, length => 20 );
    draw_tape( $tape, $context, feed => { track => 4 } );

=head1 DESCRIPTION

This package exports the function L</draw_tape> to draw nice images of
L<Punched::Tape> objects.  It uses L<Cairo> which can be used to export to
almost any image format, both vector and bitmap.

=head1 FUNCTIONS

=head2 draw_tape ( $tape, $context [, %options ] )

Draws a L<Punched::Tape> on a L<Cairo> context. There are several layout
options.

=cut

sub draw_tape {
    my ($tape, $cr, %opt) = @_;

    $opt{width}      //= 25.4;  # 25.4mm or 1 inch (another format is 17.46mm) 
    $opt{distance}   //= 2.54;  # 0.1 inch or 2.54mm between tracks
    $opt{margin}     //= 2.54;
    $opt{before}     //= 10;
    $opt{after}      //= 10;
    $opt{background} //= color( 0xEE, 0xDD, 0xDD );

    # TODO:
    # - between which tracks? (2 and 3)
    # - format (size)
    # - simple or double? (e.g. Wheatstone's had double)
    $opt{feed} = {
        track  => 2,
        radius => 1.17/2, # Feed hole diameter: 1.17mm
        double => 0,
        color  => color(0.1,0.1,0.1),
    };

	my $length = $tape->length ? $tape->length : $tape->pos;

    my $o = $opt{whole} // { };
    $o->{radius} //= 1.83/2; # code hole diameter: 1.83mm
    $o->{color}  //= color(0,0,0);

    # background
    $cr->rectangle( 0, 0, $opt{before} + $opt{distance}*$length + $opt{after}, $opt{width} );
    $cr->set_source_rgb( @{$opt{background}} );
    $cr->fill;

    my $n  = $tape->bits - 1; 
    $n++ if $opt{feed};
    my $dy = ($opt{width} - 2*$opt{margin}) / $n;
    foreach my $pos ( 0 .. $length-1 ) {
        my $x = $opt{before} + $pos * $opt{distance};
        
		my $m = $tape->bits - 1;
        if ($opt{feed}) {
            my $y = $opt{margin} + ($m-$opt{feed}->{track}) * $dy;
            $cr->arc($x,$y, $opt{feed}->{radius}, 0, 2*M_PI);
            $cr->set_source_rgb( @{$opt{feed}->{color}} );
            $cr->fill;
        }

		my $char = $tape->get($pos);

        foreach my $track ( 0 .. $m ) {
            my $y = $opt{margin} + ($m-$track) * $dy;
            if ($opt{feed}) {
                if ($track >= $opt{feed}->{track}) {
                    $y -= $dy;
                }
            }

            if ( substr($char,$track,1) eq '*' ) {
                $cr->arc($x,$y, $o->{radius}, 0, 2*M_PI);
                $cr->set_source_rgb( @{$o->{color}} );
                $cr->fill;
            } else {
                # $cr->arc($x,$y, $o->{radius}, 0, 2*M_PI);
                # $cr->set_line_width( ... );
                # $cr->set_source_rgb( 0xFF, 0xFF, 0xFF );
                # $cr->fill;
            }
        }
    }
}

sub color {
    return [ 0.0, 0.0, 0.0 ] unless @_;

    # TODO: support more formats, eg CSS colors and single numbers such as 0xEEDDEE
    return [ map { 
        $_ =~ /^\d+$/ ? $_ / 255.00 : $_; 
    } @_ ];
}

1;

=head1 TODO

Support IBM rectangular holes and double sprocket holes such as in
L<http://www.columbia.edu/cu/computinghistory/ssec-tape.html>.

=cut
