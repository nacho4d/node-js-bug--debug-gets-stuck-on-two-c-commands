package Games::Solitaire::Verify::Solution::ExpandMultiCardMoves::Lax;

use strict;
use warnings;

use Games::Solitaire::Verify::Solution::ExpandMultiCardMoves (); use vars qw(@ISA); @ISA = (qw(Games::Solitaire::Verify::Solution::ExpandMultiCardMoves));

=head1 NAME

Games::Solitaire::Verify::Solution::ExpandMultiCardMoves::Lax - faster and
laxer expansion.

=cut

our $VERSION = '0.1601';

sub _assign_read_new_state
{
    my ($self, $str) = @_;

    if (!defined($self->_state()))
    {
        $self->_state(
            Games::Solitaire::Verify::State->new(
                {
                    string => $str,
                    @{$self->_calc_variant_args()},
                }
            )
        );
    }

    return;
}

=head1 SYNOPSIS

    use Games::Solitaire::Verify::Solution::ExpandMultiCardMoves::Lax;

    my $input_filename = "freecell-24-solution.txt";

    open (my $input_fh, "<", $input_filename)
        or die "Cannot open file $!";

    # Initialise a column
    my $solution = Games::Solitaire::Verify::Solution::ExpandMultiCardMoves::Lax->new(
        {
            input_fh => $input_fh,
            variant => "freecell",
            output_fh => \*STDOUT,
        },
    );

    my $ret = $solution->verify();

    close($input_fh);

    if ($ret)
    {
        die $ret;
    }
    else
    {
        print "Solution is OK";
    }

=cut

1; # End of Games::Solitaire::Verify::Solution::ExpandMultiCardMoves::Lax
