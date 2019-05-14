#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
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
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe ::API::V3::Versions::Schemas::VersionSchemaRepresenter do
  include API::V3::Utilities::PathHelper

  let(:current_user) { FactoryBot.build_stubbed(:user) }

  let(:self_link) { '/a/self/link' }
  let(:embedded) { true }
  let(:new_record) { true }
  let(:allowed_sharings) { %w(tree system) }
  let(:allowed_status) { %w(open fixed closed) }
  let(:allowed_projects) do
    if new_record
      [FactoryBot.build_stubbed(:project),
       FactoryBot.build_stubbed(:project)]
    else
      nil
    end
  end
  let(:contract) do
    contract = double('contract')

    allow(contract)
      .to receive(:writable?) do |attribute|
      writable = %w(name description start_date due_date status sharing)

      if new_record
        writable << 'project'
      end

      writable.include?(attribute.to_s)
    end

    allow(contract)
      .to receive(:assignable_values)
      .with(:project, current_user)
      .and_return(allowed_projects)

    allow(contract)
      .to receive(:assignable_values)
      .with(:status, current_user)
      .and_return(allowed_status)

    allow(contract)
      .to receive(:assignable_values)
      .with(:sharing, current_user)
      .and_return(allowed_sharings)

    contract
  end
  let(:representer) do
    described_class.create(contract,
                           self_link,
                           form_embedded: embedded,
                           current_user: current_user)
  end

  context 'generation' do
    subject(:generated) { representer.to_json }

    describe '_type' do
      it 'is indicated as Schema' do
        is_expected.to be_json_eql('Schema'.to_json).at_path('_type')
      end
    end

    describe 'id' do
      let(:path) { 'id' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'Integer' }
        let(:name) { I18n.t('attributes.id') }
        let(:required) { true }
        let(:writable) { false }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'createdAt' do
      let(:path) { 'createdAt' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'DateTime' }
        let(:name) { Version.human_attribute_name('created_at') }
        let(:required) { true }
        let(:writable) { false }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'updatedAt' do
      let(:path) { 'updatedAt' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'DateTime' }
        let(:name) { Version.human_attribute_name('updated_at') }
        let(:required) { true }
        let(:writable) { false }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'name' do
      let(:path) { 'name' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'String' }
        let(:name) { Version.human_attribute_name('name') }
        let(:required) { true }
        let(:writable) { true }
      end

      it_behaves_like 'indicates length requirements' do
        let(:min_length) { 1 }
        let(:max_length) { 60 }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'description' do
      let(:path) { 'description' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'Formattable' }
        let(:name) { Version.human_attribute_name('description') }
        let(:required) { false }
        let(:writable) { true }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'startDate' do
      let(:path) { 'startDate' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'Date' }
        let(:name) { Version.human_attribute_name('start_date') }
        let(:required) { false }
        let(:writable) { true }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'endDate' do
      let(:path) { 'endDate' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'Date' }
        let(:name) { Version.human_attribute_name('due_date') }
        let(:required) { false }
        let(:writable) { true }
      end

      it_behaves_like 'has no visibility property'
    end

    describe 'definingProject' do
      let(:path) { 'definingProject' }

      context 'if having a new record' do
        it_behaves_like 'has basic schema properties' do
          let(:type) { 'Project' }
          let(:name) { Version.human_attribute_name('project') }
          let(:required) { true }
          let(:writable) { true }
        end

        context 'if embedding' do
          let(:embedded) { true }

          it_behaves_like 'links to and embeds allowed values directly' do
            let(:hrefs) do
              allowed_projects.map do |value|
                api_v3_paths.project(value.id)
              end
            end
          end

          it 'embeds the allowed values' do
            allowed_projects.each_with_index do |project, index|
              href_path = "#{path}/_embedded/allowedValues/#{index}/identifier"

              is_expected.to be_json_eql(project.identifier.to_json).at_path(href_path)
            end
          end
        end

        context 'if not embedding' do
          let(:embedded) { false }

          it_behaves_like 'does not link to allowed values'
        end
      end

      context 'if having a persisted record' do
        let(:new_record) { false }

        it_behaves_like 'has basic schema properties' do
          let(:type) { 'Project' }
          let(:name) { Version.human_attribute_name('project') }
          let(:required) { true }
          let(:writable) { false }
        end

        context 'if not embedding' do
          let(:embedded) { false }

          it_behaves_like 'does not link to allowed values'
        end
      end
    end

    describe 'status' do
      let(:path) { 'status' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'String' }
        let(:name) { Version.human_attribute_name('status') }
        let(:required) { true }
        let(:writable) { true }
      end

      it 'contains no link to the allowed values' do
        is_expected
          .not_to have_json_path("#{path}/_links/allowedValues")
      end

      it 'embeds the allowed values' do
        allowed_path = "#{path}/_embedded/allowedValues"

        is_expected
          .to be_json_eql(allowed_status.to_json)
          .at_path(allowed_path)
      end
    end

    describe 'sharing' do
      let(:path) { 'sharing' }

      it_behaves_like 'has basic schema properties' do
        let(:type) { 'String' }
        let(:name) { Version.human_attribute_name('sharing') }
        let(:required) { true }
        let(:writable) { true }
      end

      it 'contains no link to the allowed values' do
        is_expected
          .not_to have_json_path("#{path}/_links/allowedValues")
      end

      it 'embeds the allowed values' do
        allowed_path = "#{path}/_embedded/allowedValues"

        is_expected
          .to be_json_eql(allowed_sharings.to_json)
          .at_path(allowed_path)
      end
    end

    context '_links' do
      describe 'self link' do
        it_behaves_like 'has an untitled link' do
          let(:link) { 'self' }
          let(:href) { self_link }
        end

        context 'embedded in a form' do
          let(:self_link) { nil }

          it_behaves_like 'has no link' do
            let(:link) { 'self' }
          end
        end
      end
    end
  end
end