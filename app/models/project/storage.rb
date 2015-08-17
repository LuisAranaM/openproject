#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module Project::Storage
  def self.included(base)
    base.send :extend, StorageMethods
    base.send :include, ModelMethods
  end

  module ModelMethods
    ##
    # Count required disk storage for this project.
    # Returns a hash of the form:
    # 'total' => Total required disk space for this project
    # 'modules' => Hash of localization keys and required space for this module
    def count_required_storage
      storage = self.class.with_required_storage.find(id)

      {
        'total' => storage.required_disk_space,
        'modules' => {
          'label_work_package_plural' => storage.work_package_required_space,
          'project_module_wiki' => storage.wiki_required_space,
          'label_repository' => storage.repositories_required_space
        }.select { |_, v| v.presence && v > 0 }
      }
    end


    # Workaround for PG adapter returning strings on aggregate functions
    # TODO: This should be fixed and thus removed in Rails 4.
    %w[required_disk_space work_package_required_space
       wiki_required_space repositories_required_space].each do |attribute|

      define_method attribute do
        value = self.read_attribute(attribute)

        # Maintain nil value consistency with other adapters
        value.presence && value.to_i
      end
    end
  end

  module StorageMethods
    ##
    # Count required disk storage used by Projects.
    # This currently provides the following values
    #
    #  - +wiki_required_space+ required disk space from attachments on the wiki
    #  - +work_package_required_space+ required disk space from attachments on work packages
    #  - +repositories_required_space+ required disk space from a locally registered repository
    #  - +required_disk_space+ Total required disk space for this project over these above values.
    def with_required_storage
      Project.from("#{Project.table_name} projects")
        .joins("LEFT JOIN (#{wiki_storage_sql}) wiki ON projects.id = wiki.project_id")
        .joins("LEFT JOIN (#{work_package_sql}) wp ON projects.id = wp.project_id")
        .joins("LEFT JOIN #{Repository.table_name} repos ON repos.project_id = projects.id")
        .select('projects.*')
        .select('wiki.filesize AS wiki_required_space')
        .select('wp.filesize AS work_package_required_space')
        .select('repos.required_storage_bytes AS repositories_required_space')
        .select('(COALESCE(wiki.filesize, 0) +
                  COALESCE(wp.filesize, 0) +
                  COALESCE(repos.required_storage_bytes, 0)) AS required_disk_space')
    end

    ##
    # Returns the total required disk space for all projects in bytes
    def total_projects_size
      Project.from("(#{Project.with_required_storage.to_sql}) sub")
             .sum(:required_disk_space)
             .to_i
    end

    private

    def wiki_storage_sql
      <<-SQL
      SELECT wiki.project_id, SUM(wiki_attached.filesize) AS filesize
      FROM #{Wiki.table_name} wiki
      LEFT JOIN #{WikiPage.table_name} pages
        ON pages.wiki_id = wiki.id
      LEFT JOIN #{Attachment.table_name} wiki_attached
        ON (wiki_attached.container_id = pages.id AND wiki_attached.container_type = 'WikiPage')
      GROUP BY wiki.project_id
      SQL
    end

    def work_package_sql
      <<-SQL
      SELECT wp.project_id, SUM(wp_attached.filesize) AS filesize
      FROM #{WorkPackage.table_name} wp
      LEFT JOIN #{Attachment.table_name} wp_attached
        ON (wp_attached.container_id = wp.id AND wp_attached.container_type = 'WorkPackage')
      GROUP BY wp.project_id
      SQL
    end
  end
end
