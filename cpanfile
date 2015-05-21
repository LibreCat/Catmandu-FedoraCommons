requires 'perl', 'v5.10.1';

on 'test', sub {
  requires 'Test::Simple', '1.001003';
  requires 'Test::More', '1.001003';
  requires 'Test::Exception','0.32';
};

requires 'Catmandu', '0.9301';
requires 'Data::Validate::URI', '0.06';
requires 'Data::Validate::Type', '1.5.1';
requires 'HTTP::Request::Common', '6.06';
requires 'RDF::Trine', '1.014';
requires 'Test::JSON', '0.11';
requires 'XML::LibXML', '2.0121';

# Need recent SSL to talk to https endpoint correctly
requires 'IO::Socket::SSL', '2.015';
