Gem::Specification.new do |s|
  s.name        = 'knife-alamo'
  s.version     = '0.0.1'
  s.date        = '2012-12-05'
  s.summary     = "a knife plugin for Alamo Open Stack"
  s.description = "provides connections to chef knife"
  s.authors     = ["Paul Sims"]
  s.email       = 'paul@paulsresume.net'
  s.files       = `find lib -type f -name "*.rb"`.split("\n")
  s.homepage    =
    'http://rubygems.org/gems/knife_alamo'
  s.require_paths = ["lib"]
  s.add_dependency "chef", ">= 0.10.10"
  s.add_dependency "net-ssh", ">=2.2.2"
  s.add_dependency "net-ssh-gateway", ">=1.1"
  s.add_dependency "rest-client", ">=1.6"
end