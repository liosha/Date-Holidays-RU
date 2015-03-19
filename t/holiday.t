#!perl -T

use utf8;
use Test::More;
use Test::Exception;
use Test::Warn;

BEGIN {
	use_ok( 'Date::Holidays::RU', qw( is_holiday is_ru_holiday ) );
}

diag( "Testing Date::Holidays::RU $Date::Holidays::RU::VERSION, Perl $]" );

dies_ok { is_holiday( 1989, 3, 3 ) } 'prehistoric time';

is is_holiday( 2015, 1, 1 ), 'Новогодние каникулы', 'holiday';
is is_holiday( 2001, 1, 1 ), 'Новый год', 'old holiday name';
ok !is_holiday( 2000, 2, 23 ), 'ordinary day before becoming a holiday';
ok !is_holiday( 2014, 11, 7 ), 'ordinary day after holiday cancellation';
is is_holiday( 1996, 12, 12 ), 'День Конституции Российской Федерации', 'old holiday';

ok !is_holiday( 2014, 1, 10 ), 'business day';

is is_holiday( 2014, 3, 10 ), 'Перенос праздничного дня', 'moved holiday';
ok !is_holiday( 2013, 10, 3 ), 'not moved holiday';

ok is_holiday( 2030, 11, 4 ), q{my daughter's birthday always will be holiday :)};

is is_ru_holiday( 2015, 1, 1 ), is_holiday( 2015, 1, 1 ), 'alias';

dies_ok { is_holiday( 2015, 10, 05, 'invalid_region' ) } 'invalid region';
is is_holiday( 2015, 10, 05, 'AD' ), 'День образования Республики Адыгея', 'local holiday';
ok !is_holiday( 2015, 10, 05 ), 'local holiday in the whole country';
ok !is_holiday( 2015, 10, 05, 'BA' ), 'local holiday in other region';
is is_holiday( 2015, 10, 05, 'RU-AD' ), 'День образования Республики Адыгея', 'region alias';
is is_holiday( 2015, 02, 22, 'AL' ), 'Чага-Байрам', 'local holiday with hash tabulator';
warning_like {is_holiday( 3015, 02, 22, 'AL' )} qr/expected but not defined/, 'undefined year in hash tabulator';

done_testing();
