use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Deep;
use Clone qw/clone/;

use blib;

use_ok 'Image::SVG::Transform';

##simple revert
my $trans = Image::SVG::Transform->new(transform => 'translate(1,1)');
$trans->extract_transforms();
is_deeply $trans->transforms, [ { type => 'translate', params => [1,1], } ], 'checking setup for revert';

my $ctm = $trans->_get_ctm();
cmp_deeply dump_matrix( $ctm ),
          [
            [ 1, 0, 1 ],
            [ 0, 1, 1 ],
            [ 0, 0, 1 ],
          ],
          'Getting the combined transform matrix for a single transform';

done_testing();

sub dump_matrix {
    my $matrix = shift;
    my $dumped = [ ];
    $dumped->[0] = clone $matrix->[0];
    $dumped->[1] = clone $matrix->[1];
    $dumped->[2] = clone $matrix->[2];
    return $dumped;
}
