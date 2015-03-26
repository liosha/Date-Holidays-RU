package Date::Holidays::RU;

# ABSTRACT: Determine Russian Federation official holidays and business days.

=encoding utf8

=head1 NAME

Date::Holidays::RU

=head1 SYNOPSIS

    use Date::Holidays::RU qw( is_holiday holidays is_business_day );

    binmode STDOUT, ':encoding(UTF-8)';
   
    my ( $year, $month, $day ) = ( localtime )[ 5, 4, 3 ];
    $year  += 1900;
    $month += 1;

    if ( my $holidayname = is_holiday( $year, $month, $day ) ) {
        print "Today is a holiday: $holidayname\n";
    }
    
    my $ref = holidays( $year );
    while ( my ( $md, $name ) = each %$ref ) {
        print "On $md there is a holiday named $name\n";
    }
    
    if ( is_business_day( 2012, 03, 11 ) ) {
        print "2012-03-11 is business day on weekend\n";
    }

    if ( is_short_business_day( 2015, 04, 30 ) ) {
        print "2015-04-30 is short business day\n";
    }

=cut

use warnings;
use strict;
use utf8;
use base 'Exporter';

our @EXPORT_OK = qw(
    is_holiday
    is_ru_holiday
    holidays
    is_business_day
    is_short_business_day
);

use Carp;
use Time::Piece;
use List::Util qw/ first /;

use Date::Easter;
use Date::Hijri;


my $HOLIDAYS_VALID_SINCE = 1991;
#my $BUSINESS_DAYS_VALID_SINCE = 2004;

# sources:
#   http://ru.wikipedia.org/wiki/История_праздников_России
#   http://www.consultant.ru/popular/kzot/54_6.html#p530
#   http://www.consultant.ru/document/cons_doc_LAW_127924/?frame=17#p1681

my %REGULAR_HOLIDAYS = (
    new_year => {
        name => {
            1948 => 'Новый год',
            2005 => 'Новогодние каникулы',
        },
        days => {
            1948 => '0101',
            1992 => [ qw( 0101 0102 ) ],
            2005 => [ qw( 0101 0102 0103 0104 0105 ) ],
            2013 => [ qw( 0101 0102 0103 0104 0105 0106 0108 ) ],
        },
    },
    christmas => {
        name => 'Рождество Христово',
        days => {
            1991 => '0107', # maybe 1992
        },
    },
    defenders_day => {
        name => 'День защитника Отечества',
        days => {
            2002 => '0223',
        },
    },
    womens_day => {
        name => 'Международный женский день',
        days => {
            1966 => '0308',
        }
    },
    workers_day => {
        name => {
            1965 => 'День международной солидарности трудящихся',
            1992 => 'Праздник Весны и Труда',
        },
        days => {
            1965 => [ qw( 0501 0502 ) ],
            2005 => '0501',
        },
    },
    victory_day => {
        name => 'День Победы',
        days => {
            1965 => '0509',
        },
    },
    russia_day => {
        name => {
            1992 => 'День принятия декларации о государственном суверенитете Российской Федерации',
            2002 => 'День России',
        },
        days => {
            1992 => '0612',
        },
    },
    unity_day => {
        name => 'День народного единства',
        days => {
            2005 => '1104',
        },
    },
    revolution_day => {
        name => {
            1965 => 'Годовщина Великой Октябрьской социалистической революции',
            1996 => 'День согласия и примирения',
        },
        days => {
            1928 => [ qw( 1107 1108 ) ],
            1992 => '1107',
            2005 => undef,
        },
    },
    constitution_day => {
        name => 'День Конституции Российской Федерации',
        days => {
            1994 => '1212',
            2005 => undef,
        },
    },
);


my %HOLIDAYS_SPECIAL = (
    2004 => [ qw( 0503 0504 0510 0614 1108 1213 ) ],
    2005 => [ qw( 0106 0110 0307 0502 0613 ) ],
    2006 => [ qw( 0106 0109 0224 0508 1106 ) ],
    2007 => [ qw( 0108 0430 0611 1105 1231 ) ],
    2008 => [ qw( 0108 0225 0310 0502 0613 1103 ) ],
    2009 => [ qw( 0106 0108 0109 0309 0511 ) ],
    2010 => [ qw( 0106 0108 0222 0503 0510 0614 1105 ) ],
    2011 => [ qw( 0106 0110 0307 0502 0613 ) ],
    2012 => [ qw( 0106 0109 0309 0430 0507 0508 0611 1105 1231 ) ],
    2013 => [ qw( 0502 0503 0510 ) ],
    2014 => [ qw( 0310 0502 0613 1103 ) ],
    2015 => [ qw( 0109 0309 0504 0511 ) ],
    2016 => [ qw( 0222 0307 0502 0613 ) ],
    2017 => [ qw( 0109 0508 1106 ) ],
);


my %BUSINESS_DAYS_ON_WEEKENDS = (
    2006 => [ qw( 0226 ) ],
    2007 => [ qw( 1229 ) ],
    2008 => [ qw( 0504 0607 ) ],
    2009 => [ qw( 0111 ) ],
    2010 => [ qw( 1113 ) ],
    2012 => [ qw( 0311 0505 ) ],
);

my %SHORT_BUSINESS_DAYS = (
    2004 => [ qw( 0106 0430 0611 1231 ) ],
    2005 => [ qw( 0222 0305 1103 ) ],
    2006 => [ qw( 0222 0307 0506 1103 ) ],
    2007 => [ qw( 0222 0307 0428 0508 0609 ) ],
    2008 => [ qw( 0222 0307 0430 0508 0611 1101 1231 ) ],
    2009 => [ qw( 0430 0508 0611 1103 1231 ) ],
    2010 => [ qw( 0227 0430 0611 1103 1231 ) ],
    2011 => [ qw( 0222 0305 1103 ) ],
    2012 => [ qw( 0222 0307 0428 0512 0609 1229 ) ],
    2013 => [ qw( 0222 0307 0430 0508 0611 1231 ) ],
    2014 => [ qw( 0224 0307 0430 0508 0611 1231 ) ],
    2015 => [ qw( 0430 0508 0611 1103 1231 ) ],
    2016 => [ qw( 0227 0305 1103 ) ],
    2017 => [ qw( 0222 0307 0506 1103 ) ],
);


# sources:
#   http://base.garant.ru/4029129/
#   https://ru.wikipedia.org/wiki/%D0%9A%D0%B0%D1%82%D0%B5%D0%B3%D0%BE%D1%80%D0%B8%D1%8F:%D0%9F%D1%80%D0%B0%D0%B7%D0%B4%D0%BD%D0%B8%D0%BA%D0%B8_%D0%A0%D0%BE%D1%81%D1%81%D0%B8%D0%B8
# region codes are from ISO 3166-2: https://ru.wikipedia.org/wiki/ISO_3166-2:RU

my %REGIONAL_HOLIDAYS = (
    AD => {
        republic_day => {
            name => 'День образования Республики Адыгея',
            days => {
                2006 => '1005',
            },
        },
        eid_al_fitr => {
            name => 'Ураза-Байрам',
            days => {
                2006 => \&_calc_eid_al_fitr_date,
            },
        },
    },
    AL => {
        tsagaan_sar => {
            name => 'Чага-Байрам',
            days => {
                2013 => _get_tabulator({ 2013 => '0217', 2014 => '0202', 2015 => '0222' }),
            },
        },
    },
    # http://variant52.ru/kalendar/proizvodstvennyj-kalendar-rb-2015.htm
    BA => {
        republic_day => {
            name => 'День Республики',
            days => {
                2005 => '1011',
            },
        },
        constitution_day => {
            name => 'День Конституции Республики Башкортостан',
            days => {
                2005 => '1224',
                2010 => undef,
            },
        },
        eid_al_fitr => {
            name => 'Ураза-Байрам',
            days => {
                2005 => \&_calc_eid_al_fitr_date,
            },
        },
        eid_al_adha => {
            name => 'Курбан-Байрам',
            days => {
                2005 => \&_calc_eid_al_adha_date,
            },
        },
    },
    BU => {
        tsagaan_sar => {
            name => 'Сагаалган',
            days => {
                2009 => _get_tabulator({}), # todo: fill values
            },
        },
    },
    DA => {
        constitution_day => {
            name => 'День Конституции Республики Дагестан',
            days => {
                1995 => '0726',
            },
        },
        unity_day => {
            name => 'День единства народов Дагестана',
            days => {
                2011 => '0915',
            },
        },
        eid_al_fitr => {
            name => 'Ураза-Байрам',
            days => {
                1991 => \&_calc_eid_al_fitr_date,
            },
        },
        eid_al_adha => {
            name => 'Курбан-Байрам',
            days => {
                2000 => \&_calc_eid_al_adha_date,
            },
        },
    },
    IN => {
        republic_day => {
            name => 'День образования республики Ингушетия',
            days => {
                1996 => '0604',
                2004 => undef,
            },
        },
        # eid_al_fitr?
        # eid_al_adha?
    },
    KB => {
        revival_day => {
            name => 'День возрождения балкарского народа',
            days => {
                1994 => '0328',
            },
        },
        memorial_day => {
            name => 'День памяти адыгов (черкесов) - жертв Русско-Кавказской войны',
            days => {
                1992 => '0521',
            },
        },
        republic_day => {
            name => 'День Республики',
            days => {
                1997 => '0901',
            },
        },
        # eid_al_fitr?
        # eid_al_adha?
    },
    KL => {
        constitution_day => {
            name => 'День принятия Степного Уложения (Конституции) Республики Калмыкия',
            days => {
                2005 => '0405',
            },
        },
        memorial_day => {
            name => 'День памяти жертв депортации калмыцкого народа',
            days => {
                2005 => '1228',
            },
        },
        tsagaan_sar => {
            name => 'Цаган Сар',
            days => {
                2005 => _get_tabulator({}), # todo: fill values
            },
        },
        buddha_day => {
            name => 'День рождения Будды Шакьямуни',
            days => {
                2005 => _get_tabulator({}), # todo: fill values
            },
        },
        zula => {
            name => 'Зул',
            days => {
                2005 => _get_tabulator({}), # todo: fill values
            },
        },
    },
    KC => {
        revival_day => {
            name => 'День возрождения карачаевского народа',
            days => {
                2001 => '0503',
            },
        },
        # eid_al_fitr?
        # eid_al_adha?
    },
    SA => {
        republic_day => {
            name => 'День Республики Саха (Якутия)',
            days => {
                1992 => '0427',
            },
        },
        yhyakh => {
            name => 'День национального  праздника "Ысыах"',
            days => {
                1992 => '0621',
            },
        },
    },
    # http://mtsz.tatarstan.ru/rus/info.php?id=131384
    TA => {
        republic_day => {
            name => 'День Республики Татарстан',
            days => {
                1992 => '0830',
            },
        },
        constitution_day => {
            name => 'День Конституции Республики Татарстан',
            days => {
                1992 => '1106',
            },
        },
        eid_al_fitr => {
            name => 'Ураза-Байрам',
            days => {
                2011 => \&_calc_eid_al_fitr_date,
            },
        },
        eid_al_adha => {
            name => 'Курбан-Байрам',
            days => {
                1992 => \&_calc_eid_al_adha_date,
            },
        },
    },
    TY => {
        constitution_day => {
            name => 'День Конституции Республики Тыва',
            days => {
                1999 => '0506',
            },
        },
        republic_day => {
            name => 'День Республики Тыва',
            days => {
                1999  => '0815',
            },
        },
        tsagaan_sar => {
            name => 'Шагаа',
            days => {
                1999 => _get_tabulator({}), # todo: fill values
            },
        },
        naadym => {
            name => 'Наадым',
            days => {
                1999 => _get_tabulator({}), # todo: fill values
            },
        },
    },
    CE => {
        peace_day => {
            name => 'День мира в Чеченской Республике',
            days => {
                2010 => '0416',
            },
        },
    },
    CU => {
        republic_day => {
            name => 'День Республики',
            days => {
                2000 => '0624',
            },
        },
    },
    SAR => {
        radonitsa => {
            name => 'Радоница - день поминовения усопших',
            days => {
                2012 => \&_calc_radonitsa_date,
            },
        },
    },
);




sub _get_tabulator {
    my ($data, $default) = @_;
    my $type = ref $data;

    if ($type eq 'HASH') {
        # data ok
    }
    else {
        croak "Unsupported data type: <$type>";
    }

    return sub {
        my $year = shift;
        my $value = $data->{$year};
        if ( $default && !defined $value ) {
            $value = ref $default eq 'CODE' ? $default->($year): $default;
        }
        return $value;
    };

}


# 9th day after orthodox easter
sub _calc_radonitsa_date {
    my $year = shift;
    my ($month, $day) = orthodox_easter($year);
    my $t = Time::Piece->strptime( "$year-$month-$day", '%Y-%m-%d' ) + 60*60*(6+24*9);
    return _get_date_key($t->mon, $t->mday);
}


# known dates are for TA & BA, check for other regions
{
my $known_eid_al_fitr_date = {
    2015 => '0717',
    2014 => '0728',
    2013 => '0808',
    2012 => '0819',
    2011 => '0830',
    2010 => '0909',
    2009 => '0920',
    2008 => '0930',
    2007 => '1012',
    2006 => '1023',
};
sub _calc_eid_al_fitr_date {
    my $year = shift;
    return $known_eid_al_fitr_date->{$year} || _calc_hijri_date($year, 10, 1-1); # -1 gives better guess
}
}

{
my $known_eid_al_adha_date = {
    2015 => '0924',
    2014 => '1004',
    2013 => '1015',
    2012 => '1025',
    2011 => '1106',
    2010 => '1116',
    2009 => '1127',
    2008 => '1208',
    2007 => '1220',
    2006 => ['0110', '1231'],
};
sub _calc_eid_al_adha_date {
    my $year = shift;
    return $known_eid_al_adha_date->{$year} || _calc_hijri_date($year, 12, 10-1); # -1 gives better guess
}
}


# rough calc for islamic dates, result is +-1 day
sub _calc_hijri_date {
    my ($year, $hm, $hd) = @_;

    my @results;
    my (undef, undef, $hy) = g2h(1, 1, $year);
    for my $dy (0 .. 2) {
        my ($d, $m, $y) = h2g($hd, $hm, $hy + $dy);
        next if $y != $year;
        push @results, _get_date_key($m, $d);
    }

    return \@results;
}


=head2 is_holiday( $year, $month, $day, $region )

Determine whether this date is a RU holiday. Returns holiday name or undef.

=cut

sub is_holiday {
    my ( $year, $month, $day, $region ) = @_;

    croak 'Bad params'  unless $year && $month && $day;

    return holidays($year, $region)->{ _get_date_key($month, $day) };
}

=head2 is_ru_holiday( $year, $month, $day )

Alias for is_holiday().

=cut

sub is_ru_holiday {
    goto &is_holiday;
}

=head2 holidays( $year )

Returns hash ref of all RU holidays in the year.

=cut

my %cache;
sub holidays {
    my ($year, $region) = @_;
    croak 'Bad year'  if !$year;
    $region = _get_region_key($region);

    my $cache_key = $year . $region;
    return $cache{$cache_key}  if $cache{$cache_key};

    my $holidays = _get_regular_holidays_by_year($year, $region);

    # todo: local specials
    if ( my $spec = $HOLIDAYS_SPECIAL{ $year } ) {
        $holidays->{ $_ } = 'Перенос праздничного дня'  for @$spec;
    }

    return $cache{$cache_key} = $holidays;
}

sub _get_regular_holidays_by_year {
    my ($year, $region) = @_;
    croak "RU holidays is not valid before $HOLIDAYS_VALID_SINCE"  if $year < $HOLIDAYS_VALID_SINCE;

    my %day;
    for my $holiday ( values %REGULAR_HOLIDAYS, values %{$REGIONAL_HOLIDAYS{$region} || {}} ) {
        my $days = _resolve_yhash_value($holiday->{days}, $year);
    
        if (ref $days eq 'CODE') {
            $days = $days->($year);
            carp "Value for $year is expected but not defined"  if !defined $days;
        }
        next  if !$days;

        $days = [$days]  if !ref $days;
        next  if !@$days;

        my $name = _resolve_yhash_value($holiday->{name}, $year);
        croak "Name is not defined"  if !$name; # assertion

        $day{$_} = $name  for @$days;
    }

    return \%day;
}

sub _resolve_yhash_value {
    my ($value, $year) = @_;
    
    if (ref $value eq 'HASH') {
        my $ykey = first {$year >= $_} reverse sort keys %$value;
        return  if !$ykey;
        $value = $value->{$ykey};
    }

    return $value;
}


=head2 is_business_day( $year, $month, $day, $region )

Returns true if date is a business day in RU taking holidays and weekends into account.

=cut

sub is_business_day {
    my ( $year, $month, $day, $region ) = @_;

    croak 'Bad params'  unless $year && $month && $day;

    return 0  if is_holiday( $year, $month, $day, $region );

    # check if date is a weekend
    my $t = Time::Piece->strptime( "$year-$month-$day", '%Y-%m-%d' );
    my $wday = $t->day;
    return 1  unless $wday eq 'Sat' || $wday eq 'Sun';

    # check if date is a business day on weekend
    my $ref = $BUSINESS_DAYS_ON_WEEKENDS{ $year } or return 0;

    my $md = _get_date_key($month, $day);
    for ( @$ref ) {
        return 1  if $_ eq $md;
    }

    return 0;
}

=head2 is_short_business_day( $year, $month, $day )

Returns true if date is a shortened business day in RU.

=cut

sub is_short_business_day {
    my ( $year, $month, $day ) = @_;

    my $short_days_ref = $SHORT_BUSINESS_DAYS{ $year } or return 0;

    my $date_key = _get_date_key($month, $day);
    return !!grep { $_ eq $date_key } @$short_days_ref;
}


sub _get_date_key {
    my ($month, $day) = @_;
    return sprintf '%02d%02d', $month, $day;
}


sub _get_region_key {
    my ($region) = @_;
    return q{}  if !$region;

    $region =~ s/^RU-//ix;
    # todo: list check
    croak "Unknown RU region: <$region>"  if $region !~ /^\w{2,3}$/x;
    return uc $region;
}

=head1 AUTHOR

Alexander Nalobin, C<< <alexander at nalobin.ru> >>
Aleksey Korabelshchikov, C<< <liosha at cpan.org> >>

=cut

1;
