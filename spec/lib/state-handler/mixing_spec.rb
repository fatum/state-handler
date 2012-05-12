require 'spec_helper'

describe StateHandler::Mixing do
  before do
    class DummyResponse
      include StateHandler::Mixing

      map do
        code 200 => :enabled
        code 400 => :false

        match /5\d\d/ do
          :error
        end

        code 401, 402 do
          :bad_params
        end
      end
    end
    class DuplicateDeclarationResponse
      include StateHandler::Mixing

      map do
        code 200 => :fuck_up
      end
    end
  end
  subject {
    DuplicateDeclarationResponse.new(response_struct)
    DummyResponse.new(response_struct)
  }

  describe "#exec" do
    let(:response_struct) { OpenStruct.new(:code => 401) }
    class ExecException < Exception
    end

    it "should call block from 'at' notation with multiply states" do
      expect {
        subject.exec do |r|
          r.at :bad_params, :success, :fake do
            raise ExecException
          end
          r.test { raise ArgumentError }
        end
      }.should raise_error(ExecException)
    end

    describe "#match" do
     let(:response_struct) { OpenStruct.new(:code => 500) }
     it "should call matched block" do
        expect {
          subject.exec do |r|
            r.bad_params do
              raise ExecException
            end

            r.error do
              raise ArgumentError
            end
          end
        }.should raise_error(ArgumentError)
      end
    end

    let(:response_struct) { OpenStruct.new(:code => 401) }
    it "should call block" do
      expect {
        subject.exec do |r|
          r.bad_params do
            raise ExecException
          end

          r.success do
            raise ArgumentError
          end
        end
      }.should raise_error(ExecException)
    end
  end

  describe "#codes" do
    let(:response_struct) { OpenStruct.new(:code => 401) }

    its(:bad_params?) { should be_true }
  end

  describe "#code" do
    let(:response_struct) { OpenStruct.new(:code => 200) }

    its(:enabled?) { should be_true }
    its(:false?) { should be_false }
    its(:state) { should == :enabled }

    it "should raise UnexpectedState error" do
      expect { subject.disabled? }.should raise_error(StateHandler::UnexpectedState)
    end
  end
end


