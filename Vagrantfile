# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Testbed DTNEX / ION-DTN
# ------------------------------------------------------------------
#   NODES=2 vagrant up            -> due nodi
#   NODES=3 vagrant up            -> tre nodi (default da config.yml)
#   TOPOLOGY=full NODES=3 vagrant up
#
# Il provisioning Ansible viene eseguito una sola volta, dopo che
# l'ultima VM e' stata creata, con --limit=all: cosi' i ruoli girano in
# parallelo su tutti i nodi e ogni nodo puo' conoscere la topologia
# completa (indirizzi IP e numeri IPN dei vicini).
# ------------------------------------------------------------------

require 'yaml'

CFG = YAML.load_file(File.join(File.dirname(__FILE__), 'config.yml'))

NUM_NODES = (ENV['NODES'] || CFG['nodes']).to_i
TOPOLOGY  = (ENV['TOPOLOGY'] || CFG['topology']).to_s

unless (2..CFG['max_nodes'].to_i).cover?(NUM_NODES)
  abort("[config] NODES deve essere compreso fra 2 e #{CFG['max_nodes']} (ricevuto: #{NUM_NODES})")
end

unless %w[chain full ring].include?(TOPOLOGY)
  abort("[config] TOPOLOGY deve essere una fra: chain, full, ring (ricevuto: #{TOPOLOGY})")
end

# Vicini diretti del nodo i (1-based) secondo la topologia scelta.
def neighbours_of(i, n, topology)
  case topology
  when 'chain'
    [i - 1, i + 1].select { |j| j >= 1 && j <= n }
  when 'full'
    (1..n).to_a - [i]
  when 'ring'
    (n <= 2 ? (1..n).to_a - [i] : [((i - 2) % n) + 1, (i % n) + 1].uniq)
  end
end

NODES = (1..NUM_NODES).map do |i|
  {
    'index'     => i,
    'name'      => "#{CFG['hostname_prefix']}#{i}",
    'ipn'       => CFG['ipn_base'].to_i + i,
    'ip'        => "#{CFG['network_prefix']}.#{CFG['ip_start'].to_i + i}",
    'neighbors' => neighbours_of(i, NUM_NODES, TOPOLOGY)
  }
end

Vagrant.configure('2') do |config|
  config.vm.box = CFG['box']
  config.vm.box_check_update = false

  NODES.each_with_index do |node, idx|
    last = (idx == NODES.size - 1)

    config.vm.define node['name'], primary: (idx == 0) do |m|
      m.vm.hostname = node['name']
      m.vm.network 'private_network', ip: node['ip']

      m.vm.provider 'virtualbox' do |vb|
        vb.name   = "#{CFG['vm_name_prefix']}-#{node['name']}"
        vb.memory = CFG['memory']
        vb.cpus   = CFG['cpus']
        vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
        # ION e' sensibile al clock: manteniamo la sincronizzazione con l'host
        vb.customize ['guestproperty', 'set', :id,
                      '/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold', 1000]
      end

      m.vm.provider 'libvirt' do |lv|
        lv.memory = CFG['memory']
        lv.cpus   = CFG['cpus']
      end

      # Provisioning unico sull'ultima VM, esteso a tutti gli host.
      next unless last

      m.vm.provision 'ansible' do |ansible|
        ansible.playbook           = 'site.yml'
        ansible.compatibility_mode = '2.0'
        ansible.limit              = 'all'
        ansible.groups             = { 'dtn_nodes' => NODES.map { |n| n['name'] } }
        ansible.raw_arguments      = ["--forks=#{NODES.size}"]
        ansible.extra_vars = {
          'dtn_nodes'    => NODES,
          'dtn_topology' => TOPOLOGY
        }
      end
    end
  end
end
