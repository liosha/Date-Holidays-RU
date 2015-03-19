#!perl -T

use utf8;
use Test::More;

use Date::Holidays::RU;

my %test = (
    2012 => '0424',
    2030 => '0507',
    2037 => '0414',
);

while ( my ($y, $s) = each %test ) {
    is Date::Holidays::RU::_calc_radonitsa_date($y), $s, "year $y";
}

done_testing();
