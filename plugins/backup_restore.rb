#
# Author:: Steven Danna (steve@opscode.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#



module ServerBackup
  class BackupRestore < Chef::Knife

    deps do
      require 'chef/knife/core/object_loader'
    end

    banner "knife backup restore [-d DIR]"

    option :backup_dir,
    :short => "-d DIR",
    :long => "--backup-directory DIR",
    :description => "Restore backup data from DIR.",
    :default => Chef::Config[:knife][:chef_server_backup_dir] ? Chef::Config[:knife][:chef_server_backup_dir] : File.join(".chef", "chef_server_backup")

    def run
      ui.warn "This will overwrite existing data!"
      ui.warn "Backup is at least 1 day old" if (Time.now - File.atime(config[:backup_dir])) > 86400
      ui.confirm "Do you want to restore backup, possibly overwriting exisitng data"
      nodes
      roles
      data_bags
      environments
    end

    def nodes
      restore_standard("nodes", Chef::Node)
    end

    def roles
      restore_standard("roles", Chef::Role)
    end

    def environments
      restore_standard("environments", Chef::Environment)
    end

    def data_bags
      ui.msg "Restoring data bags"
      loader = Chef::Knife::Core::ObjectLoader.new(Chef::DataBagItem, ui)
      dbags = Dir.glob(File.join(config[:backup_dir], "data_bags", '*'))
      dbags.each do |bag|
        bag_name = File.basename(bag)
        ui.msg "Creating data bag #{bag_name}"
        rest.post_rest("data", { "name" => bag_name})
        dbag_items = Dir.glob(File.join(bag, "*"))
        dbag_items.each do |item_path|
          item_name = File.basename(item_path, '.json')
          ui.msg "Restoring data_bag_item[#{bag_name}::#{item_name}]"
          item = loader.load_from("data_bags", bag_name, item_path)
          dbag = Chef::DataBagItem.new
          dbag.data_bag(bag_name)
          dbag.raw_data = item
          dbag.save
        end
      end

    end

    def restore_standard(component, klass)
      loader = Chef::Knife::Core::ObjectLoader.new(klass, ui)
      ui.msg "Restoring #{component}"
      files = Dir.glob(File.join(config[:backup_dir], component, "*.json"))
      files.each do |f|
        ui.msg "Updating #{component} from #{f}"
      end
    end

  end
end
