require 'uri/ldap'

module URI

  class LDAPS < LDAP
    DEFAULT_PORT = 636
  end
  @@schemes['LDAPS'] = LDAPS
end
