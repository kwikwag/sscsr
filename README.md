# sscsr
simple secure client-server app in ruby

## Usage

See the `test` script for example usage, both for symmetric and asymmetric encryption. 

Run `./test` to test the project.

## Design notes

* I used JSON serialization of a base64-encoded dictionary as a protocol layer. This saved me the headache of dealing with bad inputs on the server end.
* I didn't use classes as this is just a proof-of-concept and none of these methods have any state.
* Sensitive data (keys or password) is passed via the environment so that it can be removed from the filesystem. The assumption is that the environment is as safe as the process (meaning, that if someone can hack the environment, they just may as well run whatever they want).
* The environment variable `SSCSR_INSIST_ON_URANDOM`, set to `1` or `0`, determines whether to use `/dev/urandom` or `SecureRandom` (OpenSSL).
