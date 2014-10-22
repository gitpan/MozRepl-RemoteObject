#!perl -w
use strict;
use Data::Dumper;
use Test::More;

use MozRepl::RemoteObject;

my $repl;
my $ok = eval {
    $repl = MozRepl::RemoteObject->install_bridge(
        #log => [qw[ debug ]],
    );
    1;
};
if (! $ok) {
    my $err = $@;
    plan skip_all => "Couldn't connect to MozRepl: $@";
} else {
    plan tests => 19;
};

# create a nested object
sub genObj {
    my ($repl,$val) = @_;
    my $rn = $repl->name;
    my $obj = $repl->expr(<<JS)
(function(repl, val) {
    return { bar: { baz: { value: val } }, foo: 1 };
})($rn, "$val")
JS
}

my $foo = genObj($repl, 'deep');
isa_ok $foo, 'MozRepl::RemoteObject::Instance';

my $bar = $foo->{bar};
isa_ok $bar, 'MozRepl::RemoteObject::Instance';

my $baz = $bar->{baz};
isa_ok $baz, 'MozRepl::RemoteObject::Instance';

my $val = $baz->{value};
is $val, 'deep';

$val = $baz->{nonexisting};
is $val, undef, 'Nonexisting properties return undef';

ok !exists $baz->{nonexisting}, 'exists works for not existing keys';
ok exists $baz->{value}, 'exists works for existing keys';

$baz->{ 'test' } = 'foo';
is $baz->{ test }, 'foo', 'Setting a value works';

my @keys = sort $foo->__keys;
is_deeply \@keys, ['bar','foo'], 'We can get at the keys';

@keys = sort keys %$foo;
is_deeply \@keys, ['bar','foo'], 'We can get at the keys'
    or diag Dumper \@keys;

my @values = $foo->__values;
is scalar @values, 2, 'We have two values';

@values = values %$foo;
is scalar @values, 2, 'We have two values';

my $deleted = delete $foo->{bar};
@keys = sort keys %$foo;
is_deeply \@keys, ['foo'], 'We can delete an item'
    or diag Dumper \@keys;
isa_ok $deleted, 'MozRepl::RemoteObject::Instance', "The deleted value";
is $deleted->{baz}->{value}, 'deep', "The right value was deleted";

@values = values %$foo;
is scalar @values, 1, 'We also implicitly remove the value for the key';

# Test for filtering properties to the properties actually in an object
# and not including inherited properties.
ok !exists $foo->{hasOwnProperty}, "We filter properties correctly";
$repl->expr(<<'JS');
    Object.prototype.fooBar = 1;
JS

ok $foo->{fooBar}, "Object.prototype.fooBar is available in an inherited object if you know to ask for it";
is_deeply [grep { /^fooBar$/ } keys %$foo], [], "We only show properties immediate to the object";
$repl->expr(<<'JS');
    delete Object.prototype.fooBar;
JS

#my $multi = $foo->__attr([qw[ bar foo ]]);
#is scalar @$multi, 2, "Multi-fetch retrieves two values";
#is $multi->[1], 1, "... and the second value is '1'";