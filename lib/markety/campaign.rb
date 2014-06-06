module Markety
  class Campaign

    attr_reader :client, :leads, :campaign_id

    def initialize(client)
      @client = client
    end

    def request(leads, campaign_id)
      @leads       = leads
      @campaign_id = campaign_id

      raise ArgumentError, err_msg if leads.count > 100

      client.send_request(:request_campaign, message)
    end

  private

    def err_msg
      "Marketo API does not allow over 100 leads per request"
    end

    def lead_list
      emails = leads.map &:email
      emails.map do |email|
        {
          lead_key: {
            key_type: "EMAIL",
            key_value: email
          }
        }
      end
    end

    def message
      {
        source: 'MKTOWS', # hard-coding this for now??
        campaign_name: "MarketyCampaign",
        program_name: "MarketyProgram",
        lead_list: lead_list,
        program_token_list: [
          {
            attrib: {
              name: '{{my.infl_custom_token}}',
              value: 'Thank you for calling about adding a line of service to your current plan.'
            }
          }
        ]
      }
    end
  end
end

