require 'spec_helper'

describe StateHandler::Mixin do
  before do
    class DummyResponse
      include StateHandler::Mixin

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

      def timeout?
        !response
      end
    end
    class DuplicateDeclarationResponse
      include StateHandler::Mixin

      map do
        code 200 => :fuck_up
      end
    end
  end

  def create(code, &block)
    s = OpenStruct.new(:code => code)
    DuplicateDeclarationResponse.new s
    DummyResponse.new s, &block
  end

  describe "#initialize" do
    it "should handle timeut" do
      class TempException < Exception; end
      expect {
        DummyResponse.new nil do |r|
          if r.timeout?
            raise TempException
          end
        end
      }.should raise_error TempException
    end
  end

  describe "#exclude" do
    it "should call valid block" do
      expect {
        create(400) do |r|
          r.ex :bad_params do
            raise ArgumentError
          end
        end
      }.should raise_error(ArgumentError)
    end

    it "should not call block" do
      expect {
        create(401) do |r|
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
          create(4001) {  }
        }.should_not raise_error
      end
    end

    context "when no handlers" do
      it "should do nothing" do
        expect {
          create(401) {}
        }.should_not raise_error
      end
    end
  end

  describe "#exec" do
    class ExecException < Exception
    end

    it "should call block from 'at' notation with multiply states" do
      expect {
        create(401) do |r|
          r.at :bad_params, :success, :fake do
            raise ExecException
          end
          r.test { raise ArgumentError }
        end
      }.should raise_error(ExecException)
    end

    describe "#group" do
      context "when matched value with regex" do
        it "should call block" do
          expect {
            create(500) do |r|
              r.error do
                raise ExecException
              end
            end
          }.should raise_error(ExecException)
        end

        it "should call block from group :errors" do
          expect {
            create(500) do |r|
              r.errors do
                raise ExecException
              end
            end
          }.should raise_error(ExecException)
        end
      end

      it "should call block from excluded group :errors" do
        expect {
          create(200) do |r|
            r.ex :errors do
              raise ExecException
            end
          end
        }.should raise_error(ExecException)
      end

      it "should call block mapped to group :success" do
        expect {
          create(200) do |r|
            r.success do
              raise ExecException
            end
          end
        }.should raise_error(ExecException)
      end
    end

    describe "#match" do
     it "should call matched block" do
        expect {
          create(500) do |r|
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

    it "should call block" do
      expect {
        create(401) do |r|
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
    subject { create(401) {} }
    its(:bad_params?) { should be_true }
  end

  describe "#code" do
    subject { create(200) {} }

    its(:enabled?) { should be_true }
    its(:false?) { should be_false }
    its(:state) { should == :enabled }

    it "should raise UnexpectedState error" do
      expect { subject.disabled? }.should raise_error(StateHandler::UnexpectedState)
    end
  end
end


