use strict;
use warnings;
use Test::More;
use Test::Exception;

use blib;

use_ok 'Image::SVG::Transform';

my $trans = Image::SVG::Transform->new(transform => 'skewX(1)');
lives_ok { $trans->extract_transforms() } 'parses a single skewX command';
is_deeply $trans->transforms(), [ { type => 'skewX', params => [1], }], '... validate parameters';

lives_ok { $trans->extract_transforms('skewY(4)'); } 'parses a single skewY command, two args';
is_deeply $trans->transforms(), [ { type => 'skewY', params => [4], }], '... validate parameters';

dies_ok { $trans->extract_transforms('skewX()'); } 'skewX dies on too few arguments';
like $@, qr'No parameters for transform skewX', 'correct error message';

done_testing();
