require './models/model'

module Forms
	VALID_EMAIL_REGEX = /.+@.+\..+/

	class Invite < Model
		field :person_name,                  String, :label => 'Name'
		field :person_email,                 String, :match => VALID_EMAIL_REGEX, :label => 'Email address'
		field :person_is_manager,            Boolean
	end

	class Signup < Model
		field :person_email,                 String, :required => true, :match => /.+@.+\.gov\.uk$/, :min => 5, :label => 'Email address'
		field :person_name,                  String, :required => true, :min => 2, :label => 'Name'
		field :person_is_manager,            Boolean
		field :department_name,              String, :required => true
		field :service_name,                 String, :required => true
		field :invite_users,                 Boolean
		field :invites,                      Array, :of => Invite

		def subject
			"[PaaS Support] #{Date.today.to_s} Registration Request"
		end

		def message
			msg = [
				"New organisation/account signup request from website",
				"",
				"From: #{person_name}",
				"Email: #{person_email} #{"(org manager)" if person_is_manager}",
				"Department: #{department_name}",
				"Team/Service: #{service_name}",
			].join("\n")
			if invite_users
				msg << ([
					"",
					"They would also like to invite:",
				] + invites.map{ |invite| "#{invite.person_email} #{"(org manager)" if invite.person_is_manager}" }).join("\n")
			end
			msg
		end

		def to_zendesk_ticket()
			ticket = {}
			ticket[:subject] = subject
			ticket[:comment] = { body: message }
			ticket[:requester] = {
				email: person_email,
				name: person_name,
			}
			ticket[:tags] = [ 'govuk_paas_support', 'govuk_paas_product_page' ]
			ticket[:group_id] = ENV['ZENDESK_GROUP_ID'].to_i if ENV['ZENDESK_GROUP_ID']
			ticket
		end
	end

	class Contact < Model
		MAX_FIELD_LEN = 2048

		field :person_email,                 String, :required => true, :match => VALID_EMAIL_REGEX, :min => 5, :max => MAX_FIELD_LEN, :label => 'Email address'
		field :person_name,                  String, :required => true, :min => 2, :max => MAX_FIELD_LEN, :label => 'Name'
		field :message,                      String, :required => true, :max => MAX_FIELD_LEN, :min => 1
		field :department_name,              String, :required => true
		field :service_name,                 String, :required => true

		def subject
			"[PaaS Support] #{Date.today.to_s} support request from website"
		end

		def rendered_message
			[
				"From: #{person_name}",
				"Email: #{person_email}",
				"Department: #{department_name}",
				"Team/Service: #{service_name}",
				"",
				message || '',
			].join("\n")
		end

		def to_zendesk_ticket()
			ticket = {}
			ticket[:subject] = subject
			ticket[:comment] = { body: rendered_message }
			ticket[:requester] = {
				email: person_email,
				name: person_name,
			}
			ticket[:tags] = [ 'govuk_paas_support', 'govuk_paas_product_page' ]
			ticket[:group_id] = ENV['ZENDESK_GROUP_ID'].to_i if ENV['ZENDESK_GROUP_ID']
			ticket
		end
	end

	module Helpers

		# return comma seperated list of errors from validation if resourse has been validated
		def errors_for(record, field)
			return nil if !record.validated?
			errs = record.errors[field]
			return nil if !errs or errs.size == 0
			return errs.join(", ")
		end

		def input_for(record, name, **kwargs)
			field = record.class.fields[name]
			raise "#{record} has no field #{name}" if not field
			erb :"partials/_input", :locals => {
				name: name,
				label: kwargs[:label] || name.to_s.gsub(/_/,' '),
				hint: kwargs[:hint] || '',
				value: record.send(name),
				error: errors_for(record, name)
			}
		end

		def radio_for(record, name, **kwargs)
			field = record.class.fields[name]
			raise "#{record} has no field #{name}" if not field
			erb :"partials/_radio", :locals => {
				name: name,
				label: kwargs[:label] || name.to_s.gsub(/_/,' '),
				hint: kwargs[:hint] || '',
				value: record.send(name),
				error: errors_for(record, name),
				options: kwargs[:options] || [],
			}
		end

	end

end
