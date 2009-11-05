package Encomp::Plugin;

use Encomp::Exporter;

Encomp::Exporter->setup_suger_features(
    applicant_isa => 'Encomp::Class::Plugin',
    as_is         => [qw/hook_to plugins/],
);

sub hook_to {
    caller->composite->add_hook(@_);
}

sub plugins {
    caller->composite->add_plugins(ref $_[0] ? @{$_[0]} : @_);
}

1;

__END__

=head1 NAME

Encomp::Plugin - Plugin

=head1 SYNOPSIS

 package Foo::Plugin;

 use Encomp::Plugin;
 
 hook_to '/initialize' => sub {
     my $self = shift;
 };

 hook_to '/dispatch/main' => sub {
     my $self = shift;
 };
 
 package main;
 
 Foo::Encompasser->operate('Foo::Controller');

=head1 AUTHOR

Satoshi Ohkubo E<lt>s.ohkubo@gmail.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
