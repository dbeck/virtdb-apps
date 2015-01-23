FieldTypeDetector = require "../fieldTypeDetector"

chai = require "chai"
should = chai.should()

sinon = require "sinon"
sinonChai = require "sinon-chai"
chai.use sinonChai

describe "FieldTypeDetector", ->
    sandbox = null

    beforeEach =>
        sandbox = sinon.sandbox.create()

    afterEach =>
        sandbox.restore()

    it "it should report enough samples if 0 is needed", ->
        detector = new FieldTypeDetector 0
        detector.enoughSamplesCollected().should.equal(true)

    it "it should report NOT enough samples if 1 sample is needed but no sample is provided", ->
        detector = new FieldTypeDetector 1
        detector.enoughSamplesCollected().should.equal(false)

    it "it should report NOT enough samples if 2 sample is needed and only 1 is provided", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1']
        detector.addSample ['asd']
        detector.enoughSamplesCollected().should.equal(false)

    it "it should report NOT enough samples if 2 sample is needed and only 1 is provided for one of the fields", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1,Field2']
        detector.addSample ['asd', '42']
        detector.addSample ['asdsdsd']
        detector.enoughSamplesCollected().should.equal(false)

    it "it should report enough samples if 2 sample is needed and 2 is provided for both of the fields", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1,Field2']
        detector.addSample ['asd','42']
        detector.addSample ['asdasdds','100']
        detector.enoughSamplesCollected().should.equal(true)

    it "it should report enough samples if 1 is needed and 1 sample is added", ->
        detector = new FieldTypeDetector 1
        detector.addHeader ['Field1']
        detector.addSample ['asd']
        detector.enoughSamplesCollected().should.equal(true)

    it "it should return null as fieldType if there were not enought samples", ->
        detector = new FieldTypeDetector 2
        fieldType = detector.getFieldType('Field1')
        should.not.exist(fieldType)
        detector.addHeader ['Field1']
        fieldType = detector.getFieldType('Field1')
        should.not.exist(fieldType)

    it "with 1 string field it should report field type as STRING", ->
        detector = new FieldTypeDetector 1
        detector.addHeader ['Field1']
        detector.addSample ['asd']
        detector.getFieldType('Field1').should.equal('STRING')

    it "with 1 int field it should report field type as INT32", ->
        detector = new FieldTypeDetector 1
        detector.addHeader ['Field1']
        detector.addSample ['42']
        detector.getFieldType('Field1').should.equal('UINT32')

    it "with only a null value field type should be STRING", ->
        detector = new FieldTypeDetector 1
        detector.addHeader ['Field1','Field2','Field3']
        detector.addSample ['-42','','42']
        detector.getFieldType('Field1').should.equal('INT32')
        detector.getFieldType('Field2').should.equal('STRING')
        detector.getFieldType('Field3').should.equal('UINT32')

    it "with an int and a string field it should report field type as STRING", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1']
        detector.addSample ['42']
        detector.addSample ['asd']
        detector.getFieldType('Field1').should.equal('STRING')

    it "with an int and a string field it should report field type as STRING even if only 1 sample is needed", ->
        detector = new FieldTypeDetector 1
        detector.addHeader ['Field1']
        detector.addSample ['42']
        detector.addSample ['asd']
        detector.getFieldType('Field1').should.equal('STRING')

    it "with an uint and an int field it should report field type as INT32", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1']
        detector.addSample ['42']
        detector.addSample ['-42']
        detector.getFieldType('Field1').should.equal('INT32')

    it "with an uint64 and an uint32 field it should report field type as UINT64", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1']
        detector.addSample ['4294967294']
        detector.addSample ['4294967295']
        detector.getFieldType('Field1').should.equal('UINT64')

    it "with an uint32 and an int32 field of which uint32 does not fit into int32 it should report field type as INT64", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1']
        detector.addSample ['4294967294']
        detector.addSample ['-2']
        detector.getFieldType('Field1').should.equal('INT64')

    it "with an uint64 and an int64 field of which uint64 does not fit into int64 it should report field type as STRING", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['Field1']
        detector.addSample ['9223372036854775807']
        detector.addSample ['-2']
        detector.getFieldType('Field1').should.equal('STRING')

    it "should be able to add header for sample csv data", ->
        detector = new FieldTypeDetector 2
        detector.addHeader ['playerID,yearID,gameNum,gameID,teamID,lgID,GP,startingPos']
        # detector.addSample ['9223372036854775807']
        # detector.addSample ['-2']
        # detector.getFieldType('Field1').should.equal('STRING')
