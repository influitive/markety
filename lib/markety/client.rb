module Markety
  def self.new_client(access_key, secret_key, end_point, options = {})
    api_version = options.fetch(:api_version, '2_3')

    client = Savon.client do
      endpoint end_point
      wsdl "http://app.marketo.com/soap/mktows/#{api_version}?WSDL"
      env_namespace "SOAP-ENV"
      namespaces({"xmlns:ns1" => "http://www.marketo.com/mktows/"})
      pretty_print_xml true
      raise_errors false
      log false if options[:log] == false
    end

    Client.new(client, Markety::AuthenticationHeader.new(access_key, secret_key))
  end

  class Client
    def initialize(savon_client, authentication_header)
      @client = savon_client
      @header = authentication_header
    end

    public

    def authenticated?
      # avoiding the request method because we want Savon Response object not a hash
      @header.set_time(DateTime.now)

      # Request a lead. Any lead.
      response = request(:get_lead,
        {"leadKey" => {"keyType"=>"IDNUM", "keyValue"=>1}},
        @header.to_hash
      )

      # if it finds the lead, great, you're authed. If it doesn't it will fail
      #   with a authentication_header_failure if you're not authed.
      response.success? || response.body[:fault][:faultstring] != "20014 - Authentication failed"
    rescue
      false
    end

    def get_lead_by_idnum(idnum)
      get_lead(LeadKey.new(LeadKeyType::IDNUM, idnum))
    end


    def get_lead_by_email(email)
      get_lead(LeadKey.new(LeadKeyType::EMAIL, email))
    end

    def set_logger(logger)
      @logger = logger
    end

    def sync_lead(email, first, last, company, mobile)
      lead_record = LeadRecord.new(email)
      lead_record.set_attribute('FirstName', first)
      lead_record.set_attribute('LastName', last)
      lead_record.set_attribute('Email', email)
      lead_record.set_attribute('Company', company)
      lead_record.set_attribute('MobilePhone', mobile)
      sync_lead_record(lead_record)
    end

    def sync_lead_record(lead_record)
      begin
        attributes = []
        lead_record.each_attribute_pair do |name, value|
          attributes << {attr_name: name, attr_value: value, attr_type: lead_record.get_attribute_type(name) }
        end

        response = send_request(:sync_lead, {
          return_lead: true,
          lead_record: {
            email: lead_record.email,
            lead_attribute_list: {
              attribute: attributes
            }
          }
        })

        return LeadRecord.from_hash(response[:success_sync_lead][:result][:lead_record])
      rescue Exception => e
        @logger.log(e) if @logger

        return { error: e.message }
      end
    end


    def sync_lead_record_on_id(lead_record)
      idnum = lead_record.idnum
      raise 'lead record id not set' if idnum.nil?

      begin
        attributes = []
        lead_record.each_attribute_pair do |name, value|
          attributes << {attr_name: name, attr_value: value}
        end

        attributes << {attr_name: 'Id', attr_type: 'string', attr_value: idnum.to_s}

        response = send_request(:sync_lead, {
          return_lead: true,
          lead_record:
          {
            lead_attribute_list: { attribute: attributes},
            id: idnum
          }
        })
        return LeadRecord.from_hash(response[:success_sync_lead][:result][:lead_record])
      rescue Exception => e
        @logger.log(e) if @logger
        return nil
      end
    end

    def add_to_list(list_name, idnum)
      list_operation(list_name, ListOperationType::ADD_TO, idnum)
    end

    def remove_from_list(list_name, idnum)
      list_operation(list_name, ListOperationType::REMOVE_FROM, idnum)
    end

    def is_member_of_list?(list_name, idnum)
      list_operation(list_name, ListOperationType::IS_MEMBER_OF, idnum)
    end

    def request_campaign(email, join_link, campaign_name, program_name)
      message = {
        source: 'MKTOWS',
        campaignName: campaign_name,
        programName: program_name,
        leadList: [
          {
            leadKey: {
              keyType: "EMAIL",
              keyValue: email
            }
          }
        ],
        programTokenList: [
          {
            attrib: {
              name: "{{my.join_link}}",
              value: join_link
            }
          }
        ]
      }

      send_request(:request_campaign, message)
    end

    def available_fields(type = "LeadRecord")
      send_request(:describe_m_object, object_name: type)
    end

    private

    def list_operation(list_name, list_operation_type, idnum)
      begin
        response = send_request(:list_operation, {
          list_operation: list_operation_type,
          strict:         'false',
          list_key: {
            key_type: 'MKTOLISTNAME',
            key_value: list_name
          },
          list_member_list: {
            lead_key: [{
              key_type: 'IDNUM',
              key_value: idnum
              }
            ]
          }
        })
        return response
      rescue Exception => e
        @logger.log(e) if @logger
        return nil
      end
    end

    def get_lead(lead_key)
      begin
        response = send_request(:get_lead, {"leadKey" => lead_key.to_hash})
        return LeadRecord.from_hash(response[:success_get_lead][:result][:lead_record_list][:lead_record])
      rescue Exception => e
        @logger.log(e) if @logger
        return nil
      end
    end

    def send_request(namespace, message)
      @header.set_time(DateTime.now)
      response = request(namespace, message, @header.to_hash)
      response.to_hash
    end

    def request(namespace, message, header)
      @client.call(namespace, message: message, soap_header: header)
    end
  end
end
