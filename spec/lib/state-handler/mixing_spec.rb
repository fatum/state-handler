require 'spec_helper'

describe StateHandler::Mixing do
  before do
    class DummyResponse
      include StateHandler::Mixing

      map do
        group :success do
          code 200 => :enabled
          code 400 => :false
        end

        group :errors do
          match /5\d\d/ => :error
          code 401, 402 do
            :bad_params
          end
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

  describe "#exclude" do
    it "should call valid block" do
      expect {
        DummyResponse.new(OpenStruct.new(:code => 400)) do |r|
          r.ex :bad_params do
            raise ArgumentError
          end
        end
      }.should raise_error(ArgumentError)
    end

    it "should not call block" do
      expect {
        DummyResponse.new(OpenStruct.new(:code => 401)) do |r|
          r.ex :bad_params do
            raise ArgumentError
          end
        end
      }.should_not raise_error
    end
  end

  describe "fails" do
    context "when handler not matched" do
      it "should do nothing" do
        expect {
          DummyResponse.new(OpenStruct.new(:code => 4001)) {  }
        }.should_not raise_error
      end
    end

    context "when no handlers" do
      it "should do nothing" do
        expect {
          DummyResponse.new(OpenStruct.new(:code => 401)) {  }
        }.should_not raise_error
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

    describe "#group" do
      let(:response_struct) { OpenStruct.new(:code => 200) }

      it "should call block from excluded group :errors" do
        expect {
          subject.exec do |r|
            r.ex :errors do
              raise ExecException
            end
          end
        }.should raise_error(ExecException)
      end

      it "should call block mapped to group :success" do
        expect {
          subject.exec do |r|
            r.success do
              raise ExecException
            end
          end
        }.should raise_error(ExecException)
      end
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


