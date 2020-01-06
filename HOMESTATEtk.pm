###############################################################################
# $Id$

package main;

# only to suppress file reload error in FHEM
sub HOMESTATEtk_Initialize() { }

package HOMESTATEtk;
use strict;
use warnings;
use POSIX;

use GPUtils qw(GP_Import);
use Data::Dumper;
use FHEM::Meta;
use Unit;
use RESIDENTStk;

# Run before module compilation
BEGIN {

    # Import from main::
    GP_Import(
        qw(
          attr
          AttrVal
          CommandAttr
          Debug
          defs
          deviceEvents
          devspec2array
          DoTrigger
          gettimeofday
          GetType
          init_done
          InternalTimer
          IsDisabled
          Log
          Log3
          modules
          PrintHash
          readingFnAttributes
          readingsBeginUpdate
          readingsBulkUpdate
          readingsBulkUpdateIfChanged
          readingsEndUpdate
          readingsSingleUpdate
          ReadingsTimestamp
          ReadingsVal
          RemoveInternalTimer
          Value

          RESIDENTStk_DoInitDev
          HOMESTATE_Initialize
          ZONESTATE_Initialize
          ROOMSTATE_Initialize
          OUTDOORSTATE_Initialize
          rtype2dev
          )
    );
}

# exorted variables ############################################################
our ( %stateSecurity, %types, %subTypes, %levelTypes, %RESIDENTStk_types,
    %RESIDENTStk_subTypes );

# package variables ############################################################
%stateSecurity = (
    en => [ 'unlocked', 'locked', 'protected', 'secured', 'guarded' ],
    de =>
      [ 'unverriegelt', 'verriegelt', 'geschützt', 'gesichert', 'überwacht' ],
    icons => [
        'status_open@yellow', 'status_standby@yellow@green',
        'status_night@green', 'status_locked@green',
        'building_security@green'
    ],
);

my %stateOnoff = (
    en => [ 'off', 'on' ],
    de => [ 'aus', 'an' ],
);

%types = (
    en => {
        HOMESTATE    => 'Home',
        ZONESTATE    => 'Indoor Area',
        ROOMSTATE    => 'Room',
        OUTDOORSTATE => 'Outdoor Area',
    },
    de => {
        HOMESTATE    => 'Zuhause',
        ZONESTATE    => 'Innenbereich',
        ROOMSTATE    => 'Raum',
        OUTDOORSTATE => 'Außenbereich',
    },
);

%subTypes = (
    en => {
        HOMESTATE => [
            'generic',       'house',
            'vacationHouse', 'apartment',
            'vacationApartment'
        ],
        ZONESTATE => [ 'indoor', 'outdoor' ],
        ROOMSTATE => [
            'generic', 'bathroom', 'living',  'dining',
            'kitchen', 'bedroom',  'hallway', 'storeroom',
            'cellar',  'attic',
        ],
        OUTDOORSTATE => [ 'generic', 'garden', 'patio', 'balcony' ],
    },
    de => {
        HOMESTATE =>
          [ 'generisch', 'Haus', 'Ferienhaus', 'Wohnung', 'Ferienwohnung' ],
        ZONESTATE => [ 'innen', 'außen' ],
        ROOMSTATE => [
            'generisch', 'Bad',          'Wohnzimmer', 'Esszimmer',
            'Küche',    'Schlafzimmer', 'Flur',       'Lagerraum',
            'Keller',    'Dachboden',
        ],
        OUTDOORSTATE => [ 'generisch', 'Garten', 'Terrasse', 'Balkon' ],
    },
);

my %readingsMap = (
    date_long      => 'calTod',
    date_short     => 'calTodS',
    daytime_long   => 'daytime',
    daytimeStage   => 'daytimeStage',
    daytimeStageLn => 'calTodDaytimeStageLn',
    daytimeT       => 'calTodDaytimeT',
    day_desc       => 'calTodDesc',

    # dstchange        => 'calTodDSTchng',

    dst_long         => 'calTodDST',
    isholiday        => 'calTodHoliday',
    isly             => 'calTodLeapyear',
    iswe             => 'calTodWeekend',
    mday             => 'calTodMonthday',
    mdayrem          => 'calTodMonthdayRem',
    monISO           => 'calTodMonthN',
    mon_long         => 'calTodMonth',
    mon_short        => 'calTodMonthS',
    rday_long        => 'calTodRel',
    seasonAstroChng  => 'calTodSAstroChng',
    seasonAstro_long => 'calTodSAstro',
    seasonMeteoChng  => 'calTodSMeteoChng',
    seasonMeteo_long => 'calTodSMeteo',
    seasonPhenoChng  => 'calTodSPhenoChng',
    seasonPheno_long => 'calTodSPheno',
    sunrise          => 'calTodSunrise',
    sunset           => 'calTodSunset',
    daytimeStages    => 'daytimeStages',
    wdaynISO         => 'calTodWeekdayN',
    wday_long        => 'calTodWeekday',
    wday_short       => 'calTodWeekdayS',
    weekISO          => 'calTodWeek',
    yday             => 'calTodYearday',
    ydayrem          => 'calTodYeardayRem',
    year             => 'calTodYear',
);

my %readingsMap_tom = (
    date_long      => 'calTom',
    date_short     => 'calTomS',
    daytimeStageLn => 'calTomDaytimeStageLn',
    daytimeT       => 'calTomDaytimeT',
    day_desc       => 'calTomDesc',

    # dstchange        => 'calTomDSTchng',

    dst_long         => 'calTomDST',
    isholiday        => 'calTomHoliday',
    isly             => 'calTomLeapyear',
    iswe             => 'calTomWeekend',
    mday             => 'calTomMonthday',
    mdayrem          => 'calTomMonthdayRem',
    monISO           => 'calTomMonthN',
    mon_long         => 'calTomMonth',
    mon_short        => 'calTomMonthS',
    rday_long        => 'calTomRel',
    seasonAstroChng  => 'calTomSAstroChng',
    seasonAstro_long => 'calTomSAstro',
    seasonMeteoChng  => 'calTomSMeteoChng',
    seasonMeteo_long => 'calTomSMeteo',
    seasonPhenoChng  => 'calTomSPhenoChng',
    seasonPheno_long => 'calTomSPheno',
    sunrise          => 'calTomSunrise',
    sunset           => 'calTomSunset',
    wdaynISO         => 'calTomWeekdayN',
    wday_long        => 'calTomWeekday',
    wday_short       => 'calTomWeekdayS',
    weekISO          => 'calTomWeek',
    yday             => 'calTomYearday',
    ydayrem          => 'calTomYeardayRem',
    year             => 'calTomYear',
);

# initialize ##################################################################
sub Initialize($) {
    my ($hash) = @_;

    $hash->{InitDevFn}   = "HOMESTATEtk::InitializeDev";
    $hash->{DefFn}       = "HOMESTATEtk::Define";
    $hash->{UndefFn}     = "HOMESTATEtk::Undefine";
    $hash->{SetFn}       = "HOMESTATEtk::Set";
    $hash->{GetFn}       = "HOMESTATEtk::Get";
    $hash->{AttrFn}      = "HOMESTATEtk::Attr";
    $hash->{NotifyFn}    = "HOMESTATEtk::Notify";
    $hash->{parseParams} = 1;

    $hash->{AttrList} =
        "disable:1,0 disabledForIntervals do_not_notify:1,0 "
      . $readingFnAttributes
      . " Lang:EN,DE DebugDate Level:-3,-2,-1,0,1,2,3,4,5,6,7,8,9";

    $hash->{AttrList} .=
      ' subType:' . join( ',', @{ $subTypes{en}{ $hash->{NAME} } } )
      unless ( $hash->{NAME} eq 'ZONESTATE' );

    my @holiday = devspec2array("TYPE=holiday,TYPE=Calendar");
    $hash->{AttrList} .=
      " HolidayDevices"
      . ( @holiday ? ':multiple,' . join( ',', @holiday ) : '' );
    $hash->{AttrList} .=
      " VacationDevices"
      . ( @holiday ? ':multiple,' . join( ',', @holiday ) : '' );
    $hash->{AttrList} .=
      " InformativeDevices"
      . ( @holiday ? ':multiple,' . join( ',', @holiday ) : '' );

    my @residents =
      devspec2array("TYPE=RESIDENTS,TYPE=ROOMMATE,TYPE=PET,TYPE=GUEST");
    $hash->{AttrList} .= " ResidentsDevices"
      . ( @residents ? ':multiple,' . join( ',', @residents ) : '' );

    my @twilight = devspec2array("TYPE=Astro,TYPE=Twilight");
    $hash->{AttrList} .=
      " AstroDevice" . ( @twilight ? ':' . join( ',', @twilight ) : '' );

    $hash->{AttrList} .=
" AstroSunrise:REAL,CIVIL,NAUTIC,ASTRONOMIC,HORIZON-9,HORIZON-8,HORIZON-7,HORIZON-6,HORIZON-5,HORIZON-4,HORIZON-3,HORIZON-2,HORIZON-1,HORIZON,HORIZON+1,HORIZON+2,HORIZON+3,HORIZON+4,HORIZON+5,HORIZON+6,HORIZON+7,HORIZON+8,HORIZON+9";
    $hash->{AttrList} .=
" AstroSunset:REAL,CIVIL,NAUTIC,ASTRONOMIC,HORIZON-9,HORIZON-8,HORIZON-7,HORIZON-6,HORIZON-5,HORIZON-4,HORIZON-3,HORIZON-2,HORIZON-1,HORIZON,HORIZON+1,HORIZON+2,HORIZON+3,HORIZON+4,HORIZON+5,HORIZON+6,HORIZON+7,HORIZON+8,HORIZON+9";

    my (@luminance) =
      rtype2dev( 'lx', 'lm', 'uwpsm', 'mwpscm', 'mwpsm', 'wpscm', 'wpsm' );
    my (@humidity)    = rtype2dev('pct');
    my (@motion)      = rtype2dev('yesno');
    my (@temperature) = rtype2dev('c');

    $hash->{AttrList} .= " SensorsLuminance"
      . ( @luminance ? ':multiple,' . join( ',', @luminance ) : '' );
    $hash->{AttrList} .= " SensorsHumidity"
      . ( @humidity ? ':multiple,' . join( ',', @humidity ) : '' );
    $hash->{AttrList} .=
      " SensorsMotion" . ( @motion ? ':multiple,' . join( ',', @motion ) : '' );
    $hash->{AttrList} .= " SensorsTemperature"
      . ( @temperature ? ':multiple,' . join( ',', @temperature ) : '' );

    if ( $hash->{NAME} eq 'OUTDOORSTATE' ) {
        my (@rain) = rtype2dev( 'yesno', 'mm', 'in' );
        my (@windspeed) = rtype2dev( 'bft', 'kn', 'fts', 'mph', 'kmph', 'mps' );
        $hash->{AttrList} .= " SensorsForecastTemperature"
          . ( @temperature ? ':multiple,' . join( ',', @temperature ) : '' );
        $hash->{AttrList} .=
          " SensorsRaining"
          . ( @rain ? ':multiple,' . join( ',', @rain ) : '' );
        $hash->{AttrList} .= " SensorsWindspeed"
          . ( @windspeed ? ':multiple,' . join( ',', @windspeed ) : '' );
    }

    $hash->{AttrList} .= " ThresholdDaylight";        # SUNRISE[:SUNSET]
    $hash->{AttrList} .= " ThresholdIllumination";    # MINTRIGGER[:HYSTERESIS]
    $hash->{AttrList} .= " ThresholdFreezingTemperature";
    $hash->{AttrList} .= " ThresholdRaining";         # MAXTRIGGER[:HYSTERESIS]

    if ( $hash->{NAME} ne 'HOMESTATE' ) {
        my @homestate = devspec2array("TYPE=HOMESTATE");
        $hash->{AttrList} .=
          " HomestateDevices"
          . ( @homestate ? ':' . join( ',', @homestate ) : '' );

        if ( $hash->{NAME} ne 'ZONESTATE' ) {
            my @zonestate = devspec2array("TYPE=ZONESTATE");
            $hash->{AttrList} .=
              " ZonestateDevices"
              . ( @zonestate ? ':' . join( ',', @zonestate ) : '' );
        }
    }
}

# module Fn ####################################################################
sub InitializeDev($) {
    my ($hash) = @_;
    $hash = $defs{$hash} unless ( ref($hash) );
    my $name    = $hash->{NAME};
    my $TYPE    = $hash->{TYPE};
    my $changed = 0;
    my $lang =
      lc( AttrVal( $name, "Lang", AttrVal( "global", "language", "EN" ) ) );
    my $langUc = uc($lang);
    my @error;

    delete $hash->{NEXT_EVENT};
    RemoveInternalTimer($hash);

    no strict "refs";
    &{ $TYPE . "_Initialize" }( \%{ $modules{$TYPE} } ) if ($init_done);
    use strict "refs";

    # NOTIFYDEV
    my $NOTIFYDEV = "global,$name";
    $NOTIFYDEV .= "," . findHomestateSlaves($hash);
    unless ( defined( $hash->{NOTIFYDEV} ) && $hash->{NOTIFYDEV} eq $NOTIFYDEV )
    {
        $hash->{NOTIFYDEV} = $NOTIFYDEV;
        $changed = 1;
    }

    my $time = time;
    my $debugDate = AttrVal( $name, "DebugDate", "" );
    if ( $debugDate =~
        m/^((?:\d{4}\-)?\d{2}-\d{2})(?: (\d{2}:\d{2}(?::\d{2})?))?$/ )
    {
        my $date = "$1";
        $date .= " $2" if ($2);
        my ( $sec, $min, $hour, $mday, $mon, $year ) = UConv::_time();

        $date = "$year-$date" unless ( $date =~ /^\d{4}-/ );
        $date .= "00:00:00" unless ( $date =~ /\d{2}:\d{2}:\d{2}$/ );
        $date .= ":00"      unless ( $date =~ /\d{2}:\d{2}:\d{2}$/ );
        $time = time_str2num($date);
        push @error, "WARNING: DebugDate in use ($date)";
    }

    delete $hash->{'.events'};
    delete $hash->{'.t'};
    $hash->{'.t'} = GetDaySchedule( $hash, $time, undef, $lang );
    $hash->{'.events'} = $hash->{'.t'}{events};

    ## begin reading updates
    #
    readingsBeginUpdate($hash);

    foreach ( sort keys %{ $hash->{'.t'} } ) {
        next if ( ref( $hash->{'.t'}{$_} ) );
        my $r = defined( $readingsMap{$_} ) ? $readingsMap{$_} : undef;
        my $v = $hash->{'.t'}{$_};

        readingsBulkUpdateIfChanged( $hash, $r, $v )
          if ( defined($r) );

        $r = defined( $readingsMap_tom{$_} ) ? $readingsMap_tom{$_} : undef;
        $v = defined( $hash->{'.t'}{1}{$_} ) ? $hash->{'.t'}{1}{$_} : undef;

        readingsBulkUpdateIfChanged( $hash, $r, $v )
          if ( defined($r) && defined($v) );
    }

    unless ( $lang =~ /^en/i || !$hash->{'.t'}{$lang} ) {
        foreach ( sort keys %{ $hash->{'.t'}{$lang} } ) {
            next if ( ref( $hash->{'.t'}{$lang}{$_} ) );
            my $r =
              defined( $readingsMap{$_} )
              ? $readingsMap{$_} . "_$langUc"
              : undef;
            my $v = $hash->{'.t'}{$lang}{$_};

            readingsBulkUpdateIfChanged( $hash, $r, $v )
              if ( defined($r) );

            $r =
              defined( $readingsMap_tom{$_} )
              ? $readingsMap_tom{$_} . "_$langUc"
              : undef;
            $v =
              defined( $hash->{'.t'}{1}{$lang}{$_} )
              ? $hash->{'.t'}{1}{$lang}{$_}
              : undef;

            readingsBulkUpdateIfChanged( $hash, $r, $v )
              if ( defined($r) && defined($v) );
        }
    }

    # TODO: seasonSocial
    #
    # TODO: höchster Sonnenstand
    #       > Trend Sonne aufgehend, abgehend?
    #       > temperaturmaximum 14h / 15h bei DST

    # error
    if ( scalar @error ) {
        readingsBulkUpdateIfChanged( $hash, "error", join( "; ", @error ) );
    }
    else {
        delete $hash->{READINGS}{error};
    }

    UpdateReadings($hash);
    readingsEndUpdate( $hash, 1 );

    #
    ## end reading updates

    # schedule next timer
    foreach ( sort keys %{ $hash->{'.events'} } ) {
        next if ( $_ < $time );
        $hash->{NEXT_EVENT} =
          $hash->{'.events'}{$_}{TIME} . " - " . $hash->{'.events'}{$_}{DESC};
        InternalTimer( $_, "HOMESTATEtk::InitializeDev", $hash );
        last;
    }

    return 0 unless ($changed);
    return undef;
}

sub Define($$$) {
    my ( $hash, $a, $h ) = @_;
    my $name = shift @$a;
    my $TYPE = shift @{$a};
    my $name_attr;

    $hash->{MOD_INIT}  = 1;
    $hash->{NOTIFYDEV} = "global";
    delete $hash->{NEXT_EVENT};
    RemoveInternalTimer($hash);

    # set default settings on first define
    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
        Attr( "init", $name, "Lang" );

        $attr{$name}{room} = "Homestate";
        $attr{$name}{devStateIcon} =
          '{(HOMESTATEtk::devStateIcon($name),"toggle")}';

        $attr{$name}{icon} = "control_building_control"
          if ( $TYPE eq "HOMESTATE" );
        $attr{$name}{icon} = "control_building_eg"
          if ( $TYPE eq "ZONESTATE" );
        $attr{$name}{icon} = "floor"
          if ( $TYPE eq "ROOMSTATE" );
        $attr{$name}{icon} = "scene_garden"
          if ( $TYPE eq "OUTDOORSTATE" );

        # find HOMESTATE device
        if (   $TYPE eq "ZONESTATE"
            || $TYPE eq "ROOMSTATE"
            || $TYPE eq "OUTDOORSTATE" )
        {
            my @homestates = devspec2array("TYPE=HOMESTATE");
            if ( scalar @homestates ) {
                $attr{$name}{"HomestateDevices"} = $homestates[0];
                $attr{$name}{room} = $attr{ $homestates[0] }{room}
                  if ( $attr{ $homestates[0] }
                    && $attr{ $homestates[0] }{room} );
                $attr{$name}{"Lang"} = $attr{ $homestates[0] }{Lang}
                  if ( $attr{ $homestates[0] }
                    && $attr{ $homestates[0] }{Lang} );

                Attr( "set", $name, "Lang", $attr{$name}{"Lang"} )
                  if $attr{$name}{"Lang"};
            }
            else {
                my $n = "Home";
                my $i = "";
                while ( IsDevice( $n . $i ) ) {
                    $i = 0 if ( $i eq "" );
                    $i++;
                }
                CommandDefine( undef, "$n HOMESTATE" );
                $attr{$n}{comment} =
                  "Auto-created by $TYPE module for use with HOMESTATE Toolkit";
                $attr{$name}{"HomestateDevices"} = $n;
                $attr{$name}{room}               = $attr{$n}{room};
                $attr{$name}{"Lang"}             = $attr{ $homestates[0] }{Lang}
                  if ( $attr{ $homestates[0] }
                    && $attr{ $homestates[0] }{Lang} );

                Attr( "set", $name, "Lang", $attr{$name}{"Lang"} )
                  if $attr{$name}{"Lang"};
            }
        }

        # find ROOMSTATE device
        if ( $TYPE eq "ZONESTATE" ) {
            my @roomstates = devspec2array("TYPE=ROOMSTATE");
            unless ( scalar @roomstates ) {
                my $n = "Room";
                my $i = "";
                while ( IsDevice( $n . $i ) ) {
                    $i = 0 if ( $i eq "" );
                    $i++;
                }
                CommandDefine( undef, "$n ROOMSTATE" );
                $attr{$n}{comment} =
                  "Auto-created by $TYPE module for use with HOMESTATE Toolkit";
                $attr{$name}{room} = $attr{$n}{room};
                $attr{$name}{"Lang"} = $attr{ $roomstates[0] }{Lang}
                  if ( $attr{ $roomstates[0] }
                    && $attr{ $roomstates[0] }{Lang} );

                Attr( "set", $name, "Lang", $attr{$name}{"Lang"} )
                  if $attr{$name}{"Lang"};
            }
        }

        # find RESIDENTS device
        if ( $TYPE eq "HOMESTATE" ) {
            my @residents =
              devspec2array("TYPE=RESIDENTS,TYPE=ROOMMATE,TYPE=PET");
            if ( scalar @residents ) {
                $attr{$name}{"ResidentsDevices"} = $residents[0];
                $attr{$name}{room} = $attr{ $residents[0] }{room}
                  if ( $attr{ $residents[0] } && $attr{ $residents[0] }{room} );
                $attr{$name}{"Lang"} = $attr{ $residents[0] }{rgr_lang}
                  if ( $attr{ $residents[0] }
                    && $attr{ $residents[0] }{rgr_lang} );
                $attr{$name}{"Lang"} = $attr{ $residents[0] }{rr_lang}
                  if ( $attr{ $residents[0] }
                    && $attr{ $residents[0] }{rr_lang} );

                Attr( "set", $name, "Lang", $attr{$name}{"Lang"} )
                  if $attr{$name}{"Lang"};
            }
            else {
                my $n = "rgr_Residents";
                my $i = "";
                while ( IsDevice( $n . $i ) ) {
                    $i = 0 if ( $i eq "" );
                    $i++;
                }
                CommandDefine( undef, "$n RESIDENTS" );
                $attr{$n}{comment} =
                  "Auto-created by $TYPE module for use with HOMESTATE Toolkit";
                $attr{$name}{"ResidentsDevices"} = $n;
                $attr{$n}{room} = $attr{$name}{room};

                Attr( "set", $name, "Lang", $attr{$name}{"Lang"} )
                  if $attr{$name}{"Lang"};

                $attr{$name}{group} = $attr{$n}{group};
            }
        }
    }

    my $subtype;
    $subtype = AttrVal( $name, 'subType', 'house' )
      if ( $TYPE eq 'HOMESTATE' );
    $subtype = AttrVal( $name, 'subType', 'generic' )
      if ( $TYPE eq 'ZONESTATE' );
    $subtype = AttrVal( $name, 'subType', 'living' )
      if ( $TYPE eq 'ROOMSTATE' );
    $subtype = AttrVal( $name, 'subType', 'patio' )
      if ( $TYPE eq 'OUTDOORSTATE' );
    $hash->{SUBTYPE} = $subtype;

    return undef;
}

sub Undefine($$) {
    my ( $hash, $name ) = @_;
    delete $hash->{NEXT_EVENT};
    RemoveInternalTimer($hash);
    return undef;
}

sub Set($$$);

sub Set($$$) {
    my ( $hash, $a, $h ) = @_;
    my $TYPE = $hash->{TYPE};
    my $name = shift @$a;
    my $lang =
      lc( AttrVal( $name, "Lang", AttrVal( "global", "language", "EN" ) ) );
    my $langUc   = uc($lang);
    my $state    = ReadingsVal( $name, "state", "" );
    my $mode     = ReadingsVal( $name, "mode", "" );
    my $security = ReadingsVal( $name, "security", "" );
    my $autoMode = GetIndexFromArray( ReadingsVal( $name, "autoMode", "on" ),
        $stateOnoff{en} );
    my $silent = 0;
    my %rvals;

    return undef if ( IsDisabled($name) );
    return "No argument given" unless (@$a);

    my $cmd = shift @$a;

    my $usage  = "toggle:noArg";
    my $usageL = "";

    # usage: mode
    my $i =
      defined($autoMode)
      && ReadingsVal( $name, "daytime", "night" ) ne "night"
      ? GetIndexFromArray( ReadingsVal( $name, "daytime", 0 ),
        $UConv::daytimes{en} )
      : 0;
    $usage  .= " mode:";
    $usageL .= " mode_$langUc:";
    while ( $i < scalar @{ $UConv::daytimes{en} } ) {
        last
          if ( $autoMode
            && $i == 6
            && ReadingsVal( $name, "daytime", "night" ) !~
            m/^evening|midevening|night$/ );
        if (   $autoMode
            && ReadingsVal( $name, "daytime", "night" ) eq "night"
            && $i > 3
            && $i != 6 )
        {
            $i++;
        }
        else {
            $usage  .= $UConv::daytimes{en}[$i];
            $usageL .= $UConv::daytimes{$lang}[$i];
            $i++;
            unless ( $autoMode
                && $i == 6
                && ReadingsVal( $name, "daytime", "night" ) !~
                m/^evening|midevening|night$/ )
            {
                $usage .= "," unless ( $i == scalar @{ $UConv::daytimes{en} } );
                $usageL .= ","
                  unless ( $i == scalar @{ $UConv::daytimes{$lang} } );
            }
        }
    }

    # usage: autoMode
    $usage .= " autoMode:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .= " autoMode_$langUc:" . join( ",", @{ $stateOnoff{$lang} } );

    # usage: security
    $usage .= " security:" . join( ",", @{ $stateSecurity{en} } );
    $usageL .= " security_$langUc:" . join( ",", @{ $stateSecurity{$lang} } );

    # usage: autoControlSurveillance
    $usage .= " autoControlSurveillance:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .=
      " autoControlSurveillance_$langUc:"
      . join( ",", @{ $stateOnoff{$lang} } );

    # usage: autoControlLight
    $usage .= " autoControlLight:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .=
      " autoControlLight_$langUc:" . join( ",", @{ $stateOnoff{$lang} } );

    # usage: autoControlClimate
    $usage .= " autoControlClimate:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .=
      " autoControlClimate_$langUc:" . join( ",", @{ $stateOnoff{$lang} } );

    # usage: autoControlShutters
    $usage .= " autoControlShutters:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .=
      " autoControlShutters_$langUc:" . join( ",", @{ $stateOnoff{$lang} } );

    # usage: autoControlAntiDizzle
    $usage .=
      " autoControlAntiDizzle:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .=
      " autoControlAntiDizzle_$langUc:" . join( ",", @{ $stateOnoff{$lang} } );

    # usage: autoControlShuttersShading
    $usage .=
      " autoControlShading:" . join( ",", @{ $stateOnoff{en} } );
    $usageL .=
      " autoControlShading_$langUc:" . join( ",", @{ $stateOnoff{$lang} } );

    $usage .= " $usageL" unless ( $lang eq "en" );
    return "Set usage: choose one of $usage"
      unless ( $cmd && $cmd ne "?" );

    return
      "Device is currently $security and cannot be controlled at this state"
      unless ( $security =~ m/^unlocked|locked$/ );

    # mode
    if (   $cmd eq "state"
        || $cmd eq "mode"
        || $cmd eq "state_$langUc"
        || $cmd eq "mode_$langUc"
        || grep ( m/^$cmd$/i, @{ $UConv::daytimes{en} } )
        || grep ( /^$cmd$/i,  @{ $UConv::daytimes{$lang} } ) )
    {
        $cmd = shift @$a
          if ( $cmd eq "state"
            || $cmd eq "mode"
            || $cmd eq "state_$langUc"
            || $cmd eq "mode_$langUc" );

        my $i = GetIndexFromArray( $cmd, $UConv::daytimes{en} );
        $i = GetIndexFromArray( $cmd, $UConv::daytimes{$lang} )
          unless ( $lang eq "en" || defined($i) );
        $i = $cmd
          if ( !defined($i)
            && $cmd =~ /^\d+$/
            && defined( $UConv::daytimes{en}[$cmd] ) );

        return "Invalid argument $cmd"
          unless ( defined($i) );

        my $id = GetIndexFromArray( ReadingsVal( $name, "daytime", 0 ),
            $UConv::daytimes{en} );

        if ($autoMode) {

            # during daytime, one cannot go back in time...
            $i = $id
              if ( ReadingsVal( $name, "daytime", "night" ) ne "night"
                && $i < $id );

            # evening is latest until evening itself was reached
            $i = $id if ( $i >= 6 && $id <= 3 );

            # afternoon is latest until morning was reached
            $i = 6 if ( $i >= 4 && $i != 6 && $id == 6 );
            $i = 0 if ( $i > 6 && $id == 6 );
        }

        Log3 $name, 2, "$TYPE set $name mode " . $UConv::daytimes{en}[$i];
        $rvals{mode} = $UConv::daytimes{en}[$i];
    }

    # toggle
    elsif ( $cmd eq "toggle" ) {
        my $i = GetIndexFromArray( $mode, $UConv::daytimes{en} );
        my $id = GetIndexFromArray( ReadingsVal( $name, "daytime", 0 ),
            $UConv::daytimes{en} );

        $i++;
        $i = 0 if ( $i == 7 );

        if ($autoMode) {

            # during daytime, one cannot go back in time...
            $i = $id
              if ( ReadingsVal( $name, "daytime", "night" ) ne "night"
                && $i < $id );

            # evening is latest until evening itself was reached
            $i = $id if ( $i >= 6 && $id <= 3 );

            # afternoon is latest until morning was reached
            $i = 6 if ( $i >= 4 && $i != 6 && $id == 6 );
            $i = 0 if ( $i > 6 && $id == 6 );
        }

        Log3 $name, 2, "$TYPE set $name mode " . $UConv::daytimes{en}[$i];
        $rvals{mode} = $UConv::daytimes{en}[$i];
    }

    # autoMode
    elsif ( $cmd eq "autoMode" || $cmd eq "autoMode_$langUc" ) {
        my $p1 = shift @$a;

        my $i = GetIndexFromArray( $p1, $stateOnoff{en} );
        $i = GetIndexFromArray( $p1, $stateOnoff{$lang} )
          unless ( $lang eq "en" || defined($i) );
        $i = $cmd
          if ( !defined($i)
            && $cmd =~ /^\d+$/
            && defined( $stateOnoff{en}[$cmd] ) );

        return "Invalid argument $cmd"
          unless ( defined($i) );

        Log3 $name, 2, "$TYPE set $name autoMode " . $stateOnoff{en}[$i];
        $rvals{autoMode} = $stateOnoff{en}[$i];
    }

    # usage
    else {
        return "Unknown set command $cmd, choose one of $usage";
    }

    readingsBeginUpdate($hash);

    # if autoMode changed
    if ( defined( $rvals{autoMode} ) ) {
        readingsBulkUpdateIfChanged( $hash, "autoMode", $rvals{autoMode} );
        readingsBulkUpdateIfChanged( $hash, "autoMode_$langUc",
            $stateOnoff{$lang}
              [ GetIndexFromArray( $rvals{autoMode}, $stateOnoff{en} ) ] )
          unless ( $lang eq "en" );

        if ( $rvals{autoMode} eq "on" ) {
            my $im = GetIndexFromArray( $mode, $UConv::daytimes{en} );
            my $id = GetIndexFromArray( ReadingsVal( $name, "daytime", 0 ),
                $UConv::daytimes{en} );

            $rvals{mode} = $UConv::daytimes{en}[$id]
              if ( $im < $id || ( $im == 6 && $id < 6 ) )
              ;    #TODO check when switching during evening and midevening time
        }
    }

    # if mode changed
    if ( defined( $rvals{mode} ) && $rvals{mode} ne $mode ) {
        my $modeL = ReadingsVal( $name, "mode_$langUc", "" );
        readingsBulkUpdate( $hash, "lastMode", $mode ) if ( $mode ne "" );
        readingsBulkUpdate( $hash, "lastMode_$langUc", $modeL )
          if ( $modeL ne "" );
        $mode = $rvals{mode};
        $modeL =
          $UConv::daytimes{$lang}
          [ GetIndexFromArray( $rvals{mode}, $UConv::daytimes{en} ) ];
        readingsBulkUpdate( $hash, "mode",         $mode );
        readingsBulkUpdate( $hash, "mode_$langUc", $modeL )
          unless ( $lang eq "en" );
    }

    UpdateReadings($hash);
    readingsEndUpdate( $hash, 1 );

    return undef;
}

sub Get($$$) {
    my ( $hash, $a, $h ) = @_;
    my $name = shift @$a;
    my $lang =
      lc( AttrVal( $name, "Lang", AttrVal( "global", "language", "EN" ) ) );
    my $langUc = uc($lang);

    return "No argument given" unless (@$a);

    my $cmd = shift @$a;

    my $usage = "Unknown argument $cmd, choose one of schedule";

    # schedule
    if ( $cmd eq "schedule" ) {
        my $date = shift @$a;
        my $time = shift @$a;

        if ($date) {
            return "invalid date format $date"
              unless ( !$date
                || $date =~ m/^\d{4}\-\d{2}-\d{2}$/
                || $date =~ m/^\d{2}-\d{2}$/
                || $date =~ m/^\d{10}$/ );
            return "invalid time format $time"
              unless ( !$time
                || $time =~ m/^\d{2}:\d{2}(:\d{2})?$/ );

            unless ( $date =~ m/^\d{10}$/ ) {
                my ( $sec, $min, $hour, $mday, $mon, $year ) = UConv::_time();
                $date = "$year-$date" if ( $date =~ m/^\d{2}-\d{2}$/ );
                $time .= ":00" if ( $time && $time =~ m/^\d{2}:\d{2}$/ );

                $date .= $time ? " $time" : " 00:00:00";

               # ( $year, $mon, $mday, $hour, $min, $sec ) =
               #   split( /[\s.:-]+/, $date );
               # $date = timelocal( $sec, $min, $hour, $mday, $mon - 1, $year );
                $date = time_str2num($date);
            }
        }

        #TODO timelocal? 03-26 results in wrong timestamp
        # return PrintHash(
        #     $date
        #     ? %{ GetDaySchedule( $hash, $date, undef, $lang ) }
        #       {events}
        #     : $hash->{helper}{events},
        #     3
        # );
        return PrintHash(
            $date
            ? GetDaySchedule( $hash, $date, undef, $lang )
            : $hash->{'.events'},
            3
        );
    }

    # return usage hint
    else {
        return $usage;
    }

    return undef;
}

sub Attr(@) {
    my ( $cmd, $name, $attribute, $value ) = @_;
    my $hash     = $defs{$name};
    my $TYPE     = $hash->{TYPE};
    my $security = ReadingsVal( $name, "security", "" );

    return
"Device is currently $security and attributes cannot be changed at this state"
      unless ( !$init_done || $security =~ m/^unlocked|locked$/ );

    if ( $attribute eq "subType" ) {
        return "invalid value $value"
          unless (
            $cmd eq "del"
            || defined( $subTypes{en}{$TYPE} ) && grep m/^$value$/,
            @{ $subTypes{en}{$TYPE} }
          );
        if ( $cmd eq "del" ) {
            $hash->{SUBTYPE} = 'generic';
        }
        else {
            $hash->{SUBTYPE} = $value;
        }
    }

    elsif ( $attribute eq "HomestateDevices" ) {
        return "Value for $attribute has invalid format"
          unless ( $cmd eq "del"
            || $value =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );

        delete $hash->{HOMESTATES};
        $hash->{HOMESTATES} = $value unless ( $cmd eq "del" );
    }

    elsif ( $attribute eq "ZonestateDevices" ) {
        return "Value for $attribute has invalid format"
          unless ( $cmd eq "del"
            || $value =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );

        delete $hash->{ZONESTATES};
        $hash->{ZONESTATES} = $value unless ( $cmd eq "del" );
    }

    elsif ( $attribute eq "RoomstateDevices" ) {
        return "Value for $attribute has invalid format"
          unless ( $cmd eq "del"
            || $value =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );

        delete $hash->{ROOMSTATES};
        $hash->{ROOMSTATES} = $value unless ( $cmd eq "del" );
    }

    elsif ( $attribute eq "OutdoorstateDevices" ) {
        return "Value for $attribute has invalid format"
          unless ( $cmd eq "del"
            || $value =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );

        delete $hash->{OUTDOORSTATES};
        $hash->{OUTDOORSTATES} = $value unless ( $cmd eq "del" );
    }

    elsif ( $attribute eq "ResidentsDevices" ) {
        return "Value for $attribute has invalid format"
          unless ( $cmd eq "del"
            || $value =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );

        delete $hash->{RESIDENTS};
        $hash->{RESIDENTS} = $value unless ( $cmd eq "del" );
    }

    elsif ( $attribute eq "HolidayDevices" ) {
        return "Value for $attribute has invalid format"
          unless ( $cmd eq "del"
            || $value =~ m/^[A-Za-z\d._]+(?:,[A-Za-z\d._]*)*$/ );
    }

    elsif ( $attribute eq "DebugDate" ) {
        return
            "Invalid format for $attribute. Can be:\n"
          . "\nYYYY-MM-DD"
          . "\nYYYY-MM-DD HH:MM"
          . "\nYYYY-MM-DD HH:MM:SS"
          . "\nMM-DD"
          . "\nMM-DD HH:MM"
          . "\nMM-DD HH:MM:SS"
          unless ( $cmd eq "del"
            || $value =~
            m/^((?:\d{4}\-)?\d{2}-\d{2})(?: (\d{2}:\d{2}(?::\d{2})?))?$/ );
    }

    elsif ( !$init_done ) {
        return undef;
    }

    elsif ( $attribute eq "disable" ) {
        if ( $value and $value == 1 ) {
            $hash->{STATE} = "disabled";
        }
        elsif ( $cmd eq "del" or !$value ) {
            evalStateFormat($hash);
        }
    }

    elsif ( $attribute eq "Lang" ) {
        my $lang =
          $cmd eq "set"
          ? lc($value)
          : lc( AttrVal( "global", "language", "EN" ) );
        my $langUc = uc($lang);

        # for initial define, ensure fallback to EN
        $lang = "en"
          if ( $cmd eq "init" && $lang !~ /^en|de$/i );

        if ( $lang eq "de" ) {
            $attr{$name}{alias} = "Modus"
              if ( !defined( $attr{$name}{alias} )
                || $attr{$name}{alias} eq "Mode" );
            $attr{$name}{webCmd} = "mode_$langUc:security_$langUc"
              if ( !defined( $attr{$name}{webCmd} )
                || $attr{$name}{webCmd} eq "mode" );

            if ( $TYPE eq "HOMESTATE" ) {
                $attr{$name}{group} = "Zuhause Status"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Home State" );
            }
            if ( $TYPE eq "ZONESTATE" ) {
                $attr{$name}{group} = "Zonenstatus"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Zone State" );
            }
            if ( $TYPE eq "ROOMSTATE" ) {
                $attr{$name}{group} = "Raumstatus"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Room State" );
            }
            if ( $TYPE eq "OUTDOORSTATE" ) {
                $attr{$name}{group} = "Außenstatus"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Room State" );
            }
        }

        elsif ( $lang eq "en" ) {
            $attr{$name}{alias} = "Mode"
              if ( !defined( $attr{$name}{alias} )
                || $attr{$name}{alias} eq "Modus" );
            $attr{$name}{webCmd} = "mode:security"
              if ( !defined( $attr{$name}{webCmd} )
                || $attr{$name}{webCmd} =~ /^mode_[A-Z]{2}$/ );

            if ( $TYPE eq "HOMESTATE" ) {
                $attr{$name}{group} = "Home State"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Zuhause Status" );
            }
            if ( $TYPE eq "ZONESTATE" ) {
                $attr{$name}{group} = "Zone State"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Zonenstatus" );
            }
            if ( $TYPE eq "ROOMSTATE" ) {
                $attr{$name}{group} = "Room State"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Raumstatus" );
            }
            if ( $TYPE eq "OUTDOORSTATE" ) {
                $attr{$name}{group} = "Outdoor State"
                  if ( !defined( $attr{$name}{group} )
                    || $attr{$name}{group} eq "Außenstatus" );
            }
        }
        else {
            return "Unsupported language $langUc";
        }

        $attr{$name}{$attribute} = $value if ( $cmd eq "set" );
        evalStateFormat($hash);
    }

    return undef;
}

sub Notify($$) {
    my ( $hash, $dev ) = @_;
    my $name    = $hash->{NAME};
    my $TYPE    = $hash->{TYPE};
    my $devName = $dev->{NAME};
    my $devType = GetType($devName);

    # Update attribute values
    Initialize( $modules{ $hash->{TYPE} } );

    if ( $devName eq "global" ) {
        my $events = deviceEvents( $dev, 1 );
        return "" unless ($events);

        foreach ( @{$events} ) {

            next if ( $_ =~ m/^[A-Za-z\d_-]+:/ );

            # module and device initialization
            if ( $_ =~ m/^INITIALIZED|REREADCFG$/ ) {
                if ( !defined( &{'DoInitDev'} ) ) {
                    if ( $_ eq "REREADCFG" ) {
                        delete $modules{$devType}{READY};
                        delete $modules{$devType}{INIT};
                    }
                    RESIDENTStk_DoInitDev(
                        devspec2array("TYPE=$TYPE:FILTER=MOD_INIT=.+") );
                }
            }

            # if any of our monitored devices was modified,
            # recalculate monitoring status
            elsif ( $_ =~
                m/^(DEFINED|MODIFIED|RENAMED|DELETED)\s+([A-Za-z\d_-]+)$/ )
            {
                if ( defined( &{'DoInitDev'} ) ) {

                    # DELETED would normally be handled by fhem.pl and imply
                    # DoModuleTrigger instead of DoInitDev to update module
                    # init state
                    next if ( $_ =~ /^DELETED/ );
                    DoInitDev($name);
                }
                else {

                    # for DELETED, we normally would want to use
                    # DoModuleTrigger() but we miss the deleted
                    # device's TYPE at this state :-(
                    RESIDENTStk_DoInitDev($name);
                }
            }

            # only process attribute events
            next
              unless ( $_ =~
m/^((?:DELETE)?ATTR)\s+([A-Za-z\d._]+)\s+([A-Za-z\d_\.\-\/]+)(?:\s+(.*)\s*)?$/
              );

            my $cmd  = $1;
            my $d    = $2;
            my $attr = $3;
            my $val  = $4;
            my $type = GetType($d);

            # filter attributes to be processed
            next
              unless ( $attr =~ /[Dd]evices?$/
                || $attr eq "DebugDate" );

            # when own attributes were changed
            if ( $d eq $name ) {
                if ( defined( &{'DoInitDev'} ) ) {
                    delete $hash->{NEXT_EVENT};
                    RemoveInternalTimer($hash);
                    InternalTimer( gettimeofday() + 0.5, "DoInitDev", $hash );
                }
                else {
                    delete $hash->{NEXT_EVENT};
                    RemoveInternalTimer($hash);
                    InternalTimer( gettimeofday() + 0.5,
                        "RESIDENTStk_DoInitDev", $hash );
                }
                return "";
            }
        }

        return "";
    }

    return "" if ( IsDisabled($name) or IsDisabled($devName) );

    # process events from RESIDENTS, ROOMMATE, PET or GUEST devices
    # only when they hit HOMESTATE devices
    if (   $TYPE ne $devType
        && $devType =~
        m/^HOMESTATE|ZONESTATE|ROOMSTATE|RESIDENTS|ROOMMATE|PET|GUEST$/ )
    {

        my $events = deviceEvents( $dev, 1 );
        return "" unless ($events);

        foreach my $event ( @{$events} ) {
            next unless ( defined($event) );

            # state changed
            if (   $event !~ /^[a-zA-Z\d._]+:/
                || $event =~ /^homealoneType:/
                || $event =~ /^state:/
                || $event =~ /^presence:/
                || $event =~ /^mode:/
                || $event =~ /^security:/
                || $event =~ /^wayhome:/
                || $event =~ /^wakeup:/ )
            {
                if ( defined( &{'DoInitDev'} ) ) {
                    DoInitDev($name);
                }
                else {
                    RESIDENTStk_DoInitDev($name);
                }
            }
        }

        return "";
    }

    # process own events
    elsif ( $devName eq $name ) {
        my $events = deviceEvents( $dev, 1 );
        return "" unless ($events);

        foreach my $event ( @{$events} ) {
            next unless ( defined($event) );

        }

        return "";
    }

    return "";
}

sub GetIndexFromArray($$) {
    my ( $string, $array ) = @_;
    return undef unless ( ref($array) eq "ARRAY" );
    my ($index) = grep { $array->[$_] =~ /^$string$/i } ( 0 .. @$array - 1 );
    return defined($index) ? $index : undef;
}

sub findHomestateSlaves($;$) {
    my ( $hash, $ret ) = @_;
    my $TYPE = $hash->{TYPE};
    my $name = $hash->{NAME};

    if ( $TYPE eq "HOMESTATE" ) {

        my @ZONESTATES;
        foreach ( devspec2array("TYPE=ZONESTATE") ) {
            next
              unless (
                defined( $defs{$_}{ZONESTATES} )
                && grep { $name eq $_ }
                split( /,/, $defs{$_}{ZONESTATES} )
              );
            push @ZONESTATES, $_;
        }

        if ( scalar @ZONESTATES ) {
            $hash->{ZONESTATES} = join( ",", @ZONESTATES );
        }
        elsif ( $hash->{ZONESTATES} ) {
            delete $hash->{ZONESTATES};
        }
    }

    if ( $TYPE eq "HOMESTATE" || $TYPE eq "ZONESTATE" ) {

        my @ROOMSTATES;
        foreach ( devspec2array("TYPE=ROOMSTATE") ) {
            next
              unless (
                (
                    defined( $defs{$_}{HOMESTATES} ) && grep { $name eq $_ }
                    split( /,/, $defs{$_}{HOMESTATES} )
                )
                || (
                    defined( $defs{$_}{ZONESTATES} )
                    && grep { $name eq $_ }
                    split( /,/, $defs{$_}{ZONESTATES} )
                )
              );
            push @ROOMSTATES, $_;
        }

        if ( scalar @ROOMSTATES ) {
            $hash->{ROOMSTATES} = join( ",", @ROOMSTATES );
        }
        elsif ( $hash->{ROOMSTATES} ) {
            delete $hash->{ROOMSTATES};
        }

        my @OUTDOORSTATES;
        foreach ( devspec2array("TYPE=OUTDOORSTATE") ) {
            next
              unless (
                (
                    defined( $defs{$_}{HOMESTATES} ) && grep { $name eq $_ }
                    split( /,/, $defs{$_}{HOMESTATES} )
                )
                || (
                    defined( $defs{$_}{ZONESTATES} )
                    && grep { $name eq $_ }
                    split( /,/, $defs{$_}{ZONESTATES} )
                )
              );
            push @OUTDOORSTATES, $_;
        }

        if ( scalar @OUTDOORSTATES ) {
            $hash->{OUTDOORSTATES} = join( ",", @OUTDOORSTATES );
        }
        elsif ( $hash->{OUTDOORSTATES} ) {
            delete $hash->{OUTDOORSTATES};
        }
    }

    foreach (
        qw (
        ZONESTATES
        ROOMSTATES
        OUTDOORSTATES
        RESIDENTS
        ASTRODEV
        HOLIDAYDEVS
        VACATIONDEVS
        INFODEVS
        HUMIDITYDEVS
        LUMINANCEDEVS
        MOTIONDEVS
        TEMPERATUREDEVS
        RAININGDEVS
        WINDSPEEDDEVS
        FORECASTTEMPDEVS
        )
      )
    {
        next unless ( $hash->{$_} );
        my $v = $hash->{$_};
        $v =~ s/:[^:,]*//g;
        $ret .= "," if ($ret);
        $ret .= $v;
    }

    return findDummySlaves( $hash, $ret );
}

sub findDummySlaves($;$);

sub findDummySlaves($;$) {
    my ( $hash, $ret ) = @_;
    $ret = "" unless ($ret);

    return $ret;
}

sub devStateIcon($) {
    my ($hash) = @_;
    $hash = $defs{$hash} if ( ref($hash) ne 'HASH' );

    return undef if ( !$hash );
    my $name = $hash->{NAME};
    my $lang =
      lc( AttrVal( $name, "Lang", AttrVal( "global", "language", "EN" ) ) );
    my $langUc = uc($lang);
    my @devStateIcon;

    # homeAlone
    my $i = 0;
    foreach my $TYPE ( keys %{ $RESIDENTStk_subTypes{en} } ) {
        $i = 0;
        foreach my $subType ( @{ $RESIDENTStk_subTypes{en}{$TYPE} } ) {
            $subType = $RESIDENTStk_types{en}{$TYPE}
              if ( $subType eq 'generic' );
            push @devStateIcon,
                $subType . "_.+:"
              . $RESIDENTStk_subTypes{icons}{$TYPE}[ $i++ ]
              . ":toggle";
        }
    }
    unless ( $lang ne "en" && defined( $RESIDENTStk_subTypes{$lang} ) ) {
        foreach my $TYPE ( keys %{ $RESIDENTStk_subTypes{$lang} } ) {
            $i = 0;
            foreach my $subType ( @{ $RESIDENTStk_subTypes{en}{$TYPE} } ) {
                if ( $subType eq 'generic' ) {
                    $subType = $RESIDENTStk_types{$lang}{$TYPE};
                }
                else {
                    $subType = $RESIDENTStk_subTypes{$lang}{$TYPE}[$i];
                }
                push @devStateIcon,
                    $subType . "_.+:"
                  . $RESIDENTStk_subTypes{icons}{$TYPE}[ $i++ ]
                  . ":toggle";
            }
        }
    }

    # mode
    $i = 0;
    foreach ( @{ $UConv::daytimes{en} } ) {
        push @devStateIcon,
          $_ . ":" . $UConv::daytimes{icons}[ $i++ ] . ":toggle";
    }
    if ( $lang ne "en" && defined( $UConv::daytimes{$lang} ) ) {
        $i = 0;
        foreach ( @{ $UConv::daytimes{$lang} } ) {
            push @devStateIcon,
              $_ . ":" . $UConv::daytimes{icons}[ $i++ ] . ":toggle";
        }
    }

    # security
    $i = 0;
    foreach ( @{ $stateSecurity{en} } ) {
        push @devStateIcon, $_ . ":" . $stateSecurity{icons}[ $i++ ];
    }
    if ( $lang ne "en" && defined( $UConv::daytimes{$lang} ) ) {
        $i = 0;
        foreach ( @{ $stateSecurity{$lang} } ) {
            push @devStateIcon, $_ . ":" . $stateSecurity{icons}[ $i++ ];
        }
    }

    return join( " ", @devStateIcon );
}

sub GetDaySchedule($;$$$$$) {
    my ( $hash, $time, $totalTemporalHours, $lang, @srParams ) = @_;
    my $name = $hash->{NAME};
    $lang = (
          $attr{global}{language}
        ? $attr{global}{language}
        : "EN"
    ) unless ($lang);

    return undef
      unless ( !$time || $time =~ /^\d{10}(?:\.\d+)?$/ );

    my $ret = UConv::GetDaytime( $time, $totalTemporalHours, $lang, @srParams );

    # consider user defined vacation days
    my $holidayDevs = AttrVal( $name, "HolidayDevices", "" );
    foreach my $holidayDev ( split( /,/, $holidayDevs ) ) {
        next
          unless ( IsDevice($holidayDev)
            && AttrVal( "global", "holiday2we", "" ) =~ /$holidayDev/ );

        my $date = sprintf( "%02d-%02d", $ret->{monISO}, $ret->{mday} );
        my $tod = holiday_refresh( $holidayDev, $date );
        $date =
          sprintf( "%02d-%02d", $ret->{'-1'}{monISO}, $ret->{'-1'}{mday} );
        my $ytd = holiday_refresh( $holidayDev, $date );
        $date = sprintf( "%02d-%02d", $ret->{1}{monISO}, $ret->{1}{mday} );
        my $tom = holiday_refresh( $holidayDev, $date );

        if ( $tod ne "none" ) {
            $ret->{iswe}      += 3;
            $ret->{isholiday} += 2;
            $ret->{day_desc} = $tod unless ( $ret->{isholiday} == 3 );
            $ret->{day_desc} .= ", $tod" if ( $ret->{isholiday} == 3 );
        }
        if ( $ytd ne "none" ) {
            $ret->{'-1'}{isholiday} += 2;
            $ret->{'-1'}{day_desc} = $ytd
              unless ( $ret->{'-1'}{isholiday} == 3 );
            $ret->{'-1'}{day_desc} .= ", $ytd"
              if ( $ret->{'-1'}{isholiday} == 3 );
        }
        if ( $tom ne "none" ) {
            $ret->{1}{isholiday} += 2;
            $ret->{1}{day_desc} = $tom;
            $ret->{1}{day_desc} = $tom unless ( $ret->{1}{isholiday} == 3 );
            $ret->{1}{day_desc} .= ", $tom"
              if ( $ret->{1}{isholiday} == 3 );
        }
    }

    return $ret;
}

sub UpdateReadings (@) {
    my ($hash) = @_;
    my $name   = $hash->{NAME};
    my $TYPE   = $hash->{TYPE};
    my $t      = $hash->{'.t'};
    my $state    = ReadingsVal( $name, "state",    "" );
    my $security = ReadingsVal( $name, "security", "" );
    my $daytime  = ReadingsVal( $name, "daytime",  "" );
    my $mode     = ReadingsVal( $name, "mode",     "" );
    my $autoMode = GetIndexFromArray( ReadingsVal( $name, "autoMode", "on" ),
        $stateOnoff{en} );
    my $lang =
      lc( AttrVal( $name, "Lang", AttrVal( "global", "language", "EN" ) ) );
    my $langUc = uc($lang);

    # presence
    my $state_home      = 0;
    my $state_gotosleep = 0;
    my $state_asleep    = 0;
    my $state_awoken    = 0;
    my $state_absent    = 0;
    my $state_gone      = 0;
    my $state_homealoneType;
    my $state_homealoneSubtype;
    my $wayhome        = 0;
    my $wayhomeDelayed = 0;
    my $wakeup         = 0;

    foreach my $internal ( "RESIDENTS", "ZONESTATES", "ROOMSTATES" ) {
        next unless ( $hash->{$internal} );
        foreach my $presenceDev ( split( /,/, $hash->{$internal} ) ) {
            my $state = ReadingsVal( $presenceDev, "state", "gone" );
            $state_home++      if ( $state =~ /home$/ );
            $state_gotosleep++ if ( $state =~ /gotosleep$/ );
            $state_asleep++    if ( $state =~ /asleep$/ );
            $state_awoken++    if ( $state =~ /awoken$/ );
            $state_absent++    if ( $state =~ /absent$/ );
            $state_gone++      if ( $state =~ /(?:gone|none)$/ );

            my $homealoneType =
              ReadingsVal( $presenceDev, "homealoneType", "-" );
            my $homealoneSubtype =
              ReadingsVal( $presenceDev, "homealoneSubtype", "-" );

            if (
                $homealoneType ne '-'
                && (
                    !$state_homealoneType
                    || (   $state_homealoneType eq 'PET'
                        && $homealoneType ne 'PET' )
                )
              )
            {
                $state_homealoneType    = $homealoneType;
                $state_homealoneSubtype = $homealoneSubtype;
            }

            my $wayhome = ReadingsVal( $presenceDev, "wayhome", 0 );
            $wayhome++ if ($wayhome);
            $wayhomeDelayed++ if ( $wayhome == 2 );

            my $wakeup = ReadingsVal( $presenceDev, "wakeup", 0 );
            $wakeup++ if ($wakeup);
        }
    }
    $state_home = 1
      unless ( $hash->{RESIDENTS}
        || $hash->{ZONESTATES}
        || $hash->{ROOMSTATES} );

    # autoMode
    if ( $autoMode && $mode ne $daytime ) {
        my $im = GetIndexFromArray( $mode,    $UConv::daytimes{en} );
        my $id = GetIndexFromArray( $daytime, $UConv::daytimes{en} );

        if (
            $mode eq "" || (

                # follow daymode throughout the day until midnight
                ( $im < $id && $id != 6 )

                # first change after midnight
                || ( $im >= 4 && $id == 6 )

                # morning
                || ( $im == 6 && $id >= 0 && $id <= 3 )
            )
          )
        {
            readingsBulkUpdate( $hash, "lastMode", $mode ) if ( $mode ne "" );
            $mode = $daytime;
            readingsBulkUpdate( $hash, "mode", $mode );
            unless ( $lang eq "en" ) {
                my $modeL    = ReadingsVal( $name, "mode_$langUc",    "" );
                my $daytimeL = ReadingsVal( $name, "daytime_$langUc", "" );
                readingsBulkUpdate( $hash, "lastMode_$langUc", $modeL )
                  if ( $modeL ne "" );
                readingsBulkUpdate( $hash, "mode_$langUc", $daytimeL )
                  if ( $daytimeL ne "" );
            }
        }
    }

    #
    # security calculation
    #
    my $newsecurity;

    # unsecured
    if (
           $state_home > 0
        && $mode !~ /^night|midevening$/
        && (
            !$state_homealoneType
            || (
                $state_homealoneType eq 'GUEST'
                && (   $state_homealoneSubtype eq 'guest'
                    || $state_homealoneSubtype eq 'generic'
                    || $state_homealoneSubtype eq 'domesticWorker'
                    || $state_homealoneSubtype eq 'vacationer' )
            )
        )
      )
    {
        $newsecurity = "unlocked";
    }

    # locked
    elsif (
        ( !$state_homealoneType || $state_homealoneType ne 'PET' )
        && (   $state_home > 0
            || $state_awoken > 0
            || $state_gotosleep > 0
            || $wakeup > 0 )
      )
    {
        $newsecurity = "locked";
    }

    # night or pet at home
    elsif ( $state_asleep > 0
        || ( $state_homealoneType && $state_homealoneType eq 'PET' ) )
    {
        $newsecurity = "protected";
    }

    # secured
    elsif ( $state_absent > 0 || $wayhome > 0 ) {
        $newsecurity = "secured";
    }

    # extended
    else {
        $newsecurity = "guarded";
    }

    if ( $newsecurity ne $security ) {
        readingsBulkUpdate( $hash, "lastSecurity", $security )
          if ( $security ne "" );
        $security = $newsecurity;
        readingsBulkUpdate( $hash, "security", $security );

        unless ( $lang eq "en" ) {
            my $securityL = ReadingsVal( $name, "security_$langUc", "" );
            readingsBulkUpdate( $hash, "lastSecurity_$langUc", $securityL )
              if ( $securityL ne "" );
            $securityL =
              $stateSecurity{$lang}
              [ GetIndexFromArray( $security, $stateSecurity{en} ) ];
            readingsBulkUpdate( $hash, "security_$langUc", $securityL );
        }
    }

    #
    # state calculation:
    # combine security, mode and homealone
    #
    my $newstate;
    my $statesrc;

    # mode
    if ( $security =~ m/^unlocked|locked/ ) {
        $newstate = $mode;
        $statesrc = "mode";
    }

    # security
    else {
        $newstate = $security;
        $statesrc = "security";
    }

    # homealone
    if ($state_homealoneType) {
        my $hs;
        if (   $state_homealoneSubtype eq 'generic'
            || $state_homealoneType eq 'PET' )
        {
            $hs = $RESIDENTStk_types{en}{$state_homealoneType};
        }
        else {
            $hs = $state_homealoneSubtype;
        }

        $newstate = $hs . '_' . $newstate;
    }

    if ( $newstate ne $state ) {
        readingsBulkUpdate( $hash, "lastState", $state ) if ( $state ne "" );
        readingsBulkUpdate( $hash, "state", $newstate );
        $state = $newstate;

        unless ( $lang eq "en" ) {
            my $stateL = ReadingsVal( $name, "state_$langUc", "" );
            readingsBulkUpdate( $hash, "lastState_$langUc", $stateL )
              if ( $stateL ne "" );
            $stateL = ReadingsVal( $name, $statesrc . "_$langUc", "" );

            if ($state_homealoneType) {
                my $hs;
                if (   $state_homealoneSubtype eq 'generic'
                    || $state_homealoneType eq 'PET' )
                {
                    $hs = $RESIDENTStk_types{$lang}{$state_homealoneType};
                }
                else {
                    $hs = $RESIDENTStk_subTypes{$lang}{$state_homealoneType}[
                      GetIndexFromArray( $state_homealoneSubtype,
                          $RESIDENTStk_subTypes{en}{$state_homealoneType} )
                    ];
                }
                $stateL = $hs . '_' . $stateL;
            }

            readingsBulkUpdate( $hash, "state_$langUc", $stateL );
        }
    }

}

1;

=pod
=encoding utf8

=for :application/json;q=META.json HOMESTATEtk.pm
{
  "author": [
    "Julian Pawlowski <julian.pawlowski@gmail.com>"
  ],
  "x_fhem_maintainer": [
    "loredo"
  ],
  "x_fhem_maintainer_github": [
    "jpawlowski"
  ],
  "keywords": [
    "RESIDENTS"
  ]
}
=end :application/json;q=META.json

=cut
