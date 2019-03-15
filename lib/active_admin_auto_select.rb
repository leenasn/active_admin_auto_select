require "active_admin_auto_select/version"
require "active_admin_auto_select/rails"

module AutoSelectable
  def auto_select(*fields)
    options = fields.extract_options!

    # The @resource instance variable seems unavailable in versions
    # later than 1.0.0.pre1 of the ActiveAdmin.
    resource = @resource || self.config.resource_class_name.constantize
    create_collection_action(fields, options, resource)
  end

  def create_collection_action(fields, options, resource)
    collection_action :autoselect, method: :get do
      # Rails.logger.debug "options #{options}"
      select_fields = "id, " << fields.join(", ")
      if (Module.const_get(:CanCanCan) rescue false) ? authorized?(:read, resource) : true
        term = params[:q].to_s
        term.gsub!("%", "\\\%")
        term.gsub!("_", "\\\_")
        page = params[:page].try(:to_i)
        offset = page ? (page - 1) * 10 + (5 * (page - 1)) : 0
        effective_scope = options[params[:scope]] ||
          options["default_scope"] || -> { resource }

        # This param exists when we have a filtered result
        Rails
        if params[:ids].present?
          if params[:ids].first.to_i != 0
            resources = effective_scope.call.
              where("#{resource.table_name}.id IN (?)", params[:ids]).
              select(select_fields)
            if resources.size == 1
              resources = resources.first
            else
              resources = resources.sort_by { |r| params[:ids].index(r.id.to_s) }
            end
          else
            Rails.logger.debug "tags #{params[:ids].first}"
            tags = resource.where("tag IN (?)", params[:ids].first.split(",")).send(:all_tags)
            resources = []
            tags.each do | tag |
              resources << { id: "", name: tag.humanize }
            end
            Rails.logger.debug "resources #{resources}"
          end
          render json: resources
          return
        else
          Rails.logger.debug "options #{options}"
          concat_fields = fields.join(" || ' '::text || ")
          studio = current_admin_user.super_admin? ? Studio.all : current_admin_user.studio
          # Rails.logger.debug "scope #{params[:scope]} #{params[:scope] == 'tags'}"
          if params[:scope] == "tags"
            tags = resource.where("tag LIKE '%#{term}%'").send(:all_tags)
            # resource_records = effective_scope.
            #   where("tag LIKE %#{term}%")
            resource_records = []
            tags.each do | tag |
              resource_records << { id: "", name: tag.humanize }
            end
            # render resource_records.to_json
          else
            resource_records = effective_scope.call
                           .select(select_fields)
                           .where("#{concat_fields} ILIKE :term", term: "%#{term}%")
                           .where(studio: studio)
                           .order("name")
                           .limit(15).offset(offset)
          end
          render json: resource_records
        end
      end
    end
  end
end

ActiveAdmin::ResourceDSL.send :include, AutoSelectable
