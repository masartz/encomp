package Encomp::Exporter::Spec;

use Encomp::Class ();
use Encomp::Util;
use List::MoreUtils qw/uniq/;

my %SPEC;
my %ADDED;

sub get_coated_base_exporters {
    my $applicant = shift;
    my @specific;
    for my $base (keys %{$ADDED{$applicant}}) {
        push @specific, @{$ADDED{$applicant}{$base}}, $base;
    }
    uniq @specific;
}

sub get_setup_methods {
    my $base = shift;
    @{$SPEC{$base}{setup}};
}

sub build_spec {
    my ($promoter, %args) = @_;
    return if exists $SPEC{$promoter};
    my $spec = $SPEC{$promoter} = {};
    if (my $load_class = $spec->{applicant_isa} = $args{applicant_isa}) {
        Encomp::Util::load_class($load_class);
    }
    my @uninstall;
    my $as_is = $args{as_is} || [];
    for (@{$as_is}) {
        s/^([+])//;
        push @uninstall, $_ unless $1;
    }
    my $setup = $args{setup}         || [];
    my $with  = $args{specific_with} || [];
    $setup = [ $setup ] unless ref $setup eq 'ARRAY';
    $with  = [ $with ]  unless ref $with  eq 'ARRAY';
    $spec->{as_is}         = $as_is;
    $spec->{metadata}      = $args{metadata}    || undef;
    $spec->{setup}         = $setup;
    $spec->{specific_ns}   = $args{specific_ns} || $promoter;
    $spec->{specific_with} = $with;
    $spec->{_uninstall}    = \@uninstall;
}

sub build_import {
    my $promoter = shift;
    sub {
        $^H             |= Encomp::Util::strict_bits; # strict->import;
        ${^WARNING_BITS} = $warnings::Bits{all};      # warnings->import;
        my ($class, @addons) = @_;
        my $caller = scalar caller;
        return if $class  ne $promoter;
        return if $caller eq 'main';
        my $isa    = do { no strict 'refs'; \@{$caller . '::ISA'} };
        my @loaded = _get_dependent_addons($class);
        for my $addon (_load_addons($class, @addons)) {
            push @loaded, _get_dependent_addons($addon);
        }
        @loaded = uniq @loaded;
        my @added;
        for my $super (@loaded) {
            my ($base, $metadata, $as_is) =
                @{$SPEC{$super}}{qw/applicant_isa metadata as_is/};
            if ($base) {
                unshift @{$isa}, $base unless grep m!\A$base\Z!, @{$isa};
                Encomp::Class::install_metadata($caller, $base);
            }
            my %methods;
            if (0 < @{$as_is}) {
                for my $name (@{$as_is}) {
                    $methods{$name} = $super->can($name);
                }
            }
            if ($metadata && ref $metadata eq 'HASH') {
                for my $name (keys %{$metadata}) {
                    my $data = $metadata->{$name}->($caller);
                    $methods{$name} = sub { $data };
                }
            }
            if (%methods) {
                Encomp::Util::reinstall_subroutine($caller, \%methods);
            }
            push @added, $super unless $super eq $class;
        }
        if (0 < @added) {
            my $addons = ${$ADDED{$caller} ||= {}}{$class} ||= [];
            push @{$addons}, @added;
        }
    }
}

sub build_unimport {
    my $promoter = shift;
    sub {
        my $class  = shift;
        my $caller = scalar caller;
        my @addons = ($class);
        if (exists $ADDED{$caller}{$class}) {
            push @addons, @{$ADDED{$caller}{$class}};
        }
        for my $super (reverse @addons) {
            my $uninstall = $SPEC{$super}{_uninstall};
            Encomp::Util::uninstall_subroutine($caller, @{$uninstall});
        }
        return 1;
    }
}

sub _get_dependent_addons {
    my $class = shift;
    my @isa   = reverse @{Encomp::Util::get_linear_isa($class)};
    my @addons;
    for my $super (@isa) {
        my $with = $SPEC{$super}{specific_with};
        for my $addon (_load_addons($super, @{$with})) {
            push @addons, _get_dependent_addons($addon);
        }
        push @addons, $super;
    }
    return uniq @addons, $class;
}

sub _load_addons {
    my ($class, @addons) = @_;
    my @loaded;
    my $namespace = $SPEC{$class}{specific_ns};
    for my $addon (@addons) {
        $addon =~ s/^\+/$namespace\::/;
        push @loaded, $addon if Encomp::Util::load_class($addon);
    }
    return @loaded;
}

1;

__END__
