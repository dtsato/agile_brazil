require 'spec_helper'

describe PaymentNotification do
  context "associations" do
    should_belong_to :attendee
  end
  
  context "validations" do
    should_validate_existence_of :attendee
  end
  
  context "callbacks" do
    describe "payment" do
      before(:each) do
        @attendee = Factory(:attendee)
        @attendee.should be_pending
        
        @valid_params = {
          :secret => AppConfig[:paypal][:secret],
          :receiver_email => AppConfig[:paypal][:email],
          :mc_gross => @attendee.registration_fee.to_s,
          :mc_currency => AppConfig[:paypal][:currency]
        }
        @valid_args = {
          :status => "Completed",
          :attendee => @attendee,
          :params => @valid_params
        }
      end
      
      it "succeed if status is Completed and params are valid" do
        payment_notification = Factory(:payment_notification, @valid_args)
        @attendee.should be_paid
      end
      
      it "succeed if amount paid in full" do
        @valid_params.merge!(:mc_gross => @attendee.registration_fee.to_i)
        payment_notification = Factory(:payment_notification, @valid_args)
        @attendee.should be_paid
      end

      it "fails if secret doesn't match" do
        @valid_params.merge!(:secret => 'wrong_secret')
        payment_notification = Factory(:payment_notification, @valid_args)
        @attendee.should be_pending
      end

      it "fails if status is not Completed" do
        payment_notification = Factory(:payment_notification, @valid_args.merge(:status => "Failed"))
        @attendee.should be_pending
      end

      it "fails if receiver address doesn't match" do
        @valid_params.merge!(:receiver_email => 'wrong@email.com')
        payment_notification = Factory(:payment_notification, @valid_args)
        @attendee.should be_pending
      end
      
      it "fails if paid amount doesn't match" do
        @valid_params.merge!(:mc_gross => '1.00')
        payment_notification = Factory(:payment_notification, @valid_args)
        @attendee.should be_pending
      end

      it "fails if currency doesn't match" do
        @valid_params.merge!(:mc_currency => 'GBP')
        payment_notification = Factory(:payment_notification, @valid_args)
        @attendee.should be_pending
      end
    end
  end
  
  it "should translate params from paypal into attributes" do
    paypal_params = {
      :payment_status => "Completed",
      :txn_id => "AAABBBCCC",
      :invoice => 2,
      :settle_amount => 10.5,
      :settle_currency => "USD",
      :payer_email => "payer@paypal.com",
      :memo => "Some notes from the buyer"
    }
    PaymentNotification.from_paypal_params(paypal_params).should == {
      :params => paypal_params,
      :status => "Completed",
      :transaction_id =>  "AAABBBCCC",
      :attendee_id => 2,
      :settle_amount => 10.5,
      :settle_currency => "USD",
      :payer_email => "payer@paypal.com",
      :notes => "Some notes from the buyer"
    }
  end
end