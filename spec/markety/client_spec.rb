require 'spec_helper'

module Markety
  describe Client do

    it 'should instantiate with a Savon client and authentication header' do
      client = Client.new(double('savon_client'), double('authentication_header'))
      client.class.should == Markety::Client
    end

    context "#request_campaign" do
      let(:source)      { "MKTOWS" } # hardcoded
      let(:email)       { "test@example.com" }

      let(:leads)       { [LeadRecord.new(email)] }
      let(:campaign_id) { 17 }

      it "makes a request to Marketo with request_campaign" do
        client = Client.new(double('savon_client'), double('authentication_header'))
        client.should_receive(:send_request).once
          .with(:request_campaign, {
            source: source,
            campaign_id: campaign_id,
            lead_list: [
              lead_key: {
                key_type: "EMAIL",
                key_value: email
              }
            ]
          }
        )

        response = client.request_campaign(leads, campaign_id)
      end
    end
  end
end
