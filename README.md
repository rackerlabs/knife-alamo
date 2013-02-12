knife-alamo
===========

knife-alamo provides chef knife plugin gem for Rackspace Private Cloud Software (code named Alamo). It allows you to launch and delete instances within your Rackspace Private Cloud and manage those instances through chef. The syntax mimics the existing knife plugins for Openstack.

Installation
============

1. Download the code from github
2. Build the gem:

       $ gem build knife-alamo.gemspec

3. Install the gem:

       $ sudo gem install knife-alamo-x.x.x.gem

Getting Started
===============

You can put in some default values in your ~/.chef/knife.rb file, or pass pretty much anything through the command line. Here are the knife.rb options:

These options are used to access the OpenStack API:


    knife[:alamo][:openstack_user] = "admin"
    knife[:alamo][:openstack_pass] = "adminpass"
    knife[:alamo][:openstack_tenant] = "demo"
    knife[:alamo][:openstack_region] = "RegionOne"
    knife[:alamo][:controller_ip] = "1.2.3.4"

These options are for installing chef-client on the instances. Since Rackspace Private Cloud sets up the instance fixed networks on an RFC1918 non-routable nat network, there must be a bastion device that you can reach that also has interfaces on the internal fixed network and on a routable one that you can reach.

The absolute easiest way to do this is to set up a floating IP pool and use an instance within your Private Cloud as a bastion server by connecting to the floating IP address externally.

You can theoretically use one of the compute nodes as a bastion (or even the controller), as long as there is a bridge device to the instance fixed network. The nova-network service doesn't create the necessary bridge device to the fixed-network until there is an instance on that host. In other words, if you want to use a host machine as the bastion, you have to already have an instance running to reach the instance's network. Floating IPs are really the way to go here.

    knife[:alamo][:bastion] = "4.5.6.7"
    knife[:alamo][:ssh_user] = "sshuser"
    knife[:alamo][:ssh_pass] = "sshpass"
    knife[:alamo][:key_name] = "rpcs-key"

These final configurations are for logging in to the instance and installing chef-client so you can manage it later. In the example here, the root user is the log in user. You can use non-root users, but the image you're launching *must* be allowed sudo access and must have *requiretty* disabled in /etc/sudoers. This needs to be changed on RHEL/CENTOS based distributions. To resolve, change the line in /etc/sudoers from  this:

    Defaults: requiretty

to this (using the proper username of course):

    Defaults:username !requiretty
    
Or just comment it out entirely.

    knife[:alamo][:instance_login] = "root"
    knife[:alamo][:validation_pem]  = "/Users/chef/rpcs/validation.pem"

All those options can be set on the command line. See knife's subcommand --help stuff for more info.


Usage
=====

Check your OpenStack API authentication:

    $ knife alamo auth lint
    Testing alamo auth with the following info:
	username: admin
	password: 21232f297a57a5a743894a0e4a801fc3 [md5]
	tenant: demo
	auth endpoint: http://1.2.3.4:5000/v2.0/tokens
	…
	[big json output from Keystone]

List Images:

    $ knife alamo image list
    id                                      name                                    minDisk         minRam          
    51f0b7ff-0326-4092-8568-30699e34da87    centos60                                0               0               
    97526f9a-2b5f-4a74-8040-49397585e05f    precise-image                           0               0               
    6c6028ed-77c1-451a-a378-c7c32231a872    precise-server-cloudimg-amd64-initrd    0               0               
    450f3413-fb1c-40c3-b3fa-5ceb0c823a3b    precise-server-cloudimg-amd64-kernel    0               0               
    b9a52be5-a495-40f4-a031-3c35b6615b6e    cirros-image                            0               0               
    43dd9112-afad-40d6-8455-8877fe418df2    cirros-0.3.0-x86_64-uec-initrd          0               0               
    c5caa1d0-66a8-4c4d-8932-a287376b86b1    cirros-0.3.0-x86_64-uec-kernel          0               0        


List Flavors:

    $ knife alamo flavor list
    id      name            vcpus   ram     disk    
    1       m1.tiny         1       512     0       
    2       m1.small        1       2048    10      
    3       m1.medium       2       4096    10      
    4       m1.large        4       8192    10      
    5       m1.xlarge       8       16384   10
    
Launch an Instance (chef-client is also installed):

    $ knife alamo server create --flavor 1 --image 51f0b7ff-0326-4092-8568-30699e34da87 --name instance1 --runlist 'recipe[memcached],role[webserver]'
    …
    …
    $
    
List Instances:

    $ knife alamo server list
    id                                      name                    status          addresses                       
    24aa12d1-9eeb-4716-99d7-57861ee4eb3f    instance1               ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.2"}]}


Re-run chef-client on an Instance:

    $ knife alamo server chefclient instance1
    Successfully logged in to instance. Firing up chef-client!
    …
    …
    $
    
Delete an instance:


    $ knife alamo server delete instance1
    $
    
