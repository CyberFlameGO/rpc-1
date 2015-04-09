# Changelog

## 0.3.0 

- Adding support for generating Discovery Documents without running the server
- Adding support for generating Dart client stub code from the annotated server
  code

## 0.2.0

- Disallow null to be returned from method declaring a non VoidMessage return type
- Fixed bug when encoding min/max for integers in the discovery document
- Restricted the set of ApiProperty fields depending on the type of the property
- Added min/max and type bound checking for integer and double return values
- Fixed bug with DateTime default value
- Improved error messages

## 0.1.0

- Initial version
