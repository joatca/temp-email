# temp-email

Do you often give out temporary email addresses to online services or in-person? Is it annoying to have to set them up manually each time? Want to have them auto-generated based on a regex pattern?

temp-email provides a Postfix TCP map that dynamically generates temporary, expiring valid email addresses, so that you can pick one out of the air without having to configure it in advance, provided it matches a pattern. These temporary addresses can expire after a certain time, a certain number of uses, or both. After this temp-email will pretend that they are unknown, causing Postfix to reject any email sent to them. Finally, any of the expired addresses can be "aged out" and forgotten about after a long enough period of time so they will eventually work again.

## Installation

TODO: Write installation instructions here

## Usage

### Configuration

If run as root (not recommended), temp-email reads the configuration file `/etc/temp-emailrc`. If run as a user it reads ~/.temp-emailrc. The configuration files consists of single lines that are either configuration directives or pattern lines with a target address and at least one expiry directive.

Because Postfix supports TCP maps for virtual maps but not for aliases, patterns are matched against the full destination address (user@domain) not just the local address (user).

Example:

    # this is the default port
    port 9099
	
	# maximum number of addresses that will be tracked matching a pattern - this is mainly to avoid a DOS attack
	max-per-pattern 50
    
    # any address beginning with "foo" gets sent to "bar@example.com", expiring after 48 hours
    /^foo/ diamond@example.com 48h
    
    # the same but only works 3 times:
    /^temp/ emerald@example.com 3x
    
    # both at the same time (expires either after 5 uses or 7 days, whichever happens first)
    /^paranoid/ sapphire@example.com 5x 7d
    
    # works only twice before expiring, but gets forgotten about after about 6 months
    /^spy/ salt@example.com 2x !180d
    
    # default settings for any address - if set these directives are applied to all patterns unless overridden
    * 10x !365d

In the example above if you give out the address "foo1234@example.com", Postfix receives an email to that address and queries temp-email it will match the first pattern line and be recorded in a database with an expiry date 48 hours in the future. "bar@example.com" will returned to Postfix. Subsequent queries within the 48-hour period will also return "bar@example.com". After the 48-hour period expires temp-email will start returning "unknown address" and unless the address was otherwise valid Postfix will start rejecting email to the address.

If you also give out "foo2345@example.com" it will get recorded separately in the database with its own expiry date. Up to 50 unexpired matching addresses will be tracked - if a 51st arrives temp-email will return "unknown address".

### Postfix Configuration

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/joatca/temp-email/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [joatca](https://github.com/joatca) Fraser McCrossan - creator, maintainer
