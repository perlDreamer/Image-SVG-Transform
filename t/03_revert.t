use strict;
use warnings;
use Test::More;
use Test::Exception;

use blib;

use_ok 'Image::SVG::Transform';

##simple revert
my $trans = Image::SVG::Transform->new(transform => 'translate(1,1)');
$trans->extract_transforms();
is_deeply $trans->transforms, [ { type => 'translate', params => [1,1], } ], 'checking setup for revert';
my $original = $trans->revert([2,2]);
is_deeply $original, [1,1], 'reversed a translate transform';

done_testing();
