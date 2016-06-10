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

my $view1 = $trans->revert([2, 2]);
is_deeply $view1, [ 1, 1 ], 'Undid translation from 1,1 to 2,2';

my $view2 = $trans->revert([6, 9]);
is_deeply $view2, [ 5, 8 ], 'Undid translation from 5,8 to 6,9';

$trans->extract_transforms("translate(5)");
my $view3 = $trans->revert([10, 10]);
is_deeply $view3, [5, 10], 'Undid 5,0 translation scaling from 5,10 to 10,10';

$trans->extract_transforms("scale(3)");
my $view4 = $trans->revert([36, 21]);
is_deeply $view4, [12, 7], 'Undid 3X scaling from 12,7 to 36,21';

$trans->extract_transforms("scale(2,4)");
my $view5 = $trans->revert([8, 16]);
is_deeply $view5, [4, 4], 'Undid 2,4 scaling from 4,4 to 8,16';

done_testing();

sub dump_matrix {
    my $matrix = shift;
    my $dumped = [ ];
    $dumped->[0] = clone $matrix->[0];
    $dumped->[1] = clone $matrix->[1];
    $dumped->[2] = clone $matrix->[2];
    return $dumped;
}
