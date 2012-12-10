knife-alamo
===========

knife-alamo provides chef knife plugin for Alamo's implementation of openstack. It can be used to deploy instances and get chef-client booted up to them. Here are the varibales you should care about!

* knife[:alamo][:username] = "demo" (openstack username)
* knife[:alamo][:password] = "demo" (openstack password)
* knife[:alamo][:auth_url] = "http://198.101.133.52:5000/v2.0/tokens" (keystone)
* knife[:alamo][:tenant] = "demo" (openstack tenant)
* knife[:alamo][:region] = "RegionOne" (keystone region)
* knife[:alamo][:key_name] = "idrsa" (name of your openstack ssh key)
* knife[:alamo][:bastion] = "198.101.133.52" (IP of your infra node/all-in-one. Since your instances will come up on a private network, you need to log in thru this bastion server to connect to them)
* knife[:alamo][:bastion_login] = "someuser" (ssh username to the bastion IP)
* knife[:alamo][:bastion_pass] = "secrete" (ssh password)
* knife[:alamo][:privkey_file] = "/Users/paul/.ssh/ostack.pem" (Location of your instance ssh key. If you don't set this, it will try to use $home/.ssh/id_rsa and other ssh defaults)
* knife[:alamo][:instance_login] = "ubuntu" (username to log in to the instance with. If you don't specify root, it will try for sudo. Note: Centos & rhel really want you to be root or sudo doesn't work right)
* knife[:alamo][:validation_pem] = "/Users/paul/.chef/hortonworks/validation.pem" (Chef validation.pem)

All those options can be set on the command line. See knife's subcommand --help stuff for more info.

Examples
========

    $ knife alamo server list
    id                                      name                    status          addresses                       
    0102a610-994c-4d24-84a8-163e60ee4f75    egle1                   ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.11"}]}
    98df130a-fbda-4e6d-b9a6-d83a4c0b6439    hadoopworker6           ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.10"}]}
    dafd0bbe-dded-405b-b202-19872b0a5edd    hadoopworker5           ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.6"}]}
    3eb00665-2aaf-42b2-b150-a37fd2cc2d9f    hadoopworker4           ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.8"}]}
    f6e223a4-7b2d-445a-bc40-bbdafb90b771    hadoopworker3           ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.7"}]}
    d0a31066-2e8f-4946-a58b-b2e2324423b5    hdpworker2              ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.5"}]}
    d5eb0fcd-96f2-49fd-ab6d-e0d71ba48dee    hdpworker1              ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.4"}]}
    6d511307-e2a0-4ed6-aed1-cdd6f330d0f0    hdpmaster               ACTIVE          {"public"=>[{"version"=>4, "addr"=>"172.31.0.2"}]}

    $ knife alamo image list
    id                                      name                                    minDisk         minRam          
    51f0b7ff-0326-4092-8568-30699e34da87    centos60                                0               0               
    97526f9a-2b5f-4a74-8040-49397585e05f    precise-image                           0               0               
    6c6028ed-77c1-451a-a378-c7c32231a872    precise-server-cloudimg-amd64-initrd    0               0               
    450f3413-fb1c-40c3-b3fa-5ceb0c823a3b    precise-server-cloudimg-amd64-kernel    0               0               
    b9a52be5-a495-40f4-a031-3c35b6615b6e    cirros-image                            0               0               
    43dd9112-afad-40d6-8455-8877fe418df2    cirros-0.3.0-x86_64-uec-initrd          0               0               
    c5caa1d0-66a8-4c4d-8932-a287376b86b1    cirros-0.3.0-x86_64-uec-kernel          0               0     

    $ knife alamo server create --name hadoopworker8 --image 51f0b7ff-0326-4092-8568-30699e34da87 --flavor 2 --chefenv hdp --runlist 'recipe[chef-client],role[hadoop-worker]'
    $ # Then it spins up an instance, logs in, installs chef-client, and assigns the chef environment and runlist.

    $ knife alamo server delete 51f0b7ff-0326-4092-8568-30699e34da87


Two useful functions:

    $ knife alamo auth lint # Tests your keystone auth

    $ knife alamo server chefclient 51f0b7ff-0326-4092-8568-30699e34da87 # Runs chefclient from that instance on demand