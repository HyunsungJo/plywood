{ expect } = require("chai")

{ testImmutableClass } = require("immutable-class/build/tester")

{ WallTime } = require('chronoshift')
if not WallTime.rules
  tzData = require("chronoshift/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

plywood = require('../../build/plywood')
{ Expression, Dataset, External, TimeRange, $, ply, r } = plywood

wikiDataset = External.fromJS({
  engine: 'druid',
  dataSource: 'wikipedia',
  timeAttribute: 'time',
  context: null
  attributes: {
    time: { type: 'TIME' }
    language: { type: 'STRING' }
    user: { type: 'STRING' }
    page: { type: 'STRING' }
    added: { type: 'NUMBER' }
  }
})

context = {
  wiki: wikiDataset.addFilter($('time').in(TimeRange.fromJS({
    start: new Date("2013-02-26T00:00:00Z")
    end: new Date("2013-02-27T00:00:00Z")
  })))
  wikiCmp: wikiDataset.addFilter($('time').in(TimeRange.fromJS({
    start: new Date("2013-02-25T00:00:00Z")
    end: new Date("2013-02-26T00:00:00Z")
  })))
}

describe "External", ->
  it "passes higher object tests", ->
    testImmutableClass(External, [
      {
        engine: 'druid',
        dataSource: 'moon_child',
        timeAttribute: 'time',
        context: null
        attributes: {
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          carat: { type: 'STRING' }
          price: { type: 'NUMBER', filterable: false, splitable: false }
        }
      }

      {
        engine: 'druid',
        dataSource: 'wiki',
        timeAttribute: 'time',
        allowEternity: true,
        allowSelectQueries: true,
        exactResultsOnly: true,
        context: null
      }

      {
        engine: 'druid',
        dataSource: 'moon_child2', # ToDo: remove the 2 and fix the equality test
        timeAttribute: 'time',
        context: null
        attributeOverrides: {
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          unique: { type: "STRING", special: 'unique' }
        }
      }
    ], {
      newThrows: true
    })

  describe "does not die with hasOwnProperty", ->
    it "survives", ->
      expect(External.fromJS({
        engine: 'druid',
        dataSource: 'wiki',
        timeAttribute: 'time',
        context: null,
        hasOwnProperty: 'troll'
      }).toJS()).to.deep.equal({
        engine: 'druid',
        dataSource: 'wiki',
        timeAttribute: 'time',
        context: null
      })


  describe "simplifies / digests", ->
    it "a simple select", ->
      ex = $('wiki')

      ex = ex.referenceCheck(context).resolve(context).simplify()
      expect(ex.op).to.equal('external')

    it "select, apply, filter", ->
      ex = $('wiki')
        .apply('addedTwice', '$added * 2')
        .filter($("language").is('en'))

      ex = ex.referenceCheck(context).resolve(context).simplify()
      expect(ex.op).to.equal('external')
      externalDataset = ex.external
      expect(externalDataset.derivedAttributes).to.have.all.keys(['addedTwice'])
      expect(
        externalDataset.filter.toJS()
      ).to.deep.equal(
        context.wiki.filter.and($("language", "STRING").is('en')).toJS()
      )

    it "a total", ->
      ex = ply()
        .apply("wiki",
          $('wiki', 1)
            .apply('addedTwice', '$added * 2')
            .filter($("language").is('en'))
        )
        .apply('Count', '$wiki.count()')
        .apply('TotalAdded', '$wiki.sum($added)')

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('external')
      externalDataset = ex.external
      expect(externalDataset.derivedAttributes).to.have.all.keys(['addedTwice'])
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Count: { "type": "NUMBER" },
        TotalAdded: { "type": "NUMBER" }
      })

      expect(externalDataset.simulate().toJS()).to.deep.equal([
        {
          "Count": 4
          "TotalAdded": 4
        }
      ])

    it "a split on string", ->
      ex = $('wiki').split("$page", 'Page')
        .apply('Count', '$wiki.count()')
        .apply('Added', '$wiki.sum($added)')
        .sort('$Count', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('external')
      externalDataset = ex.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.limit.limit).to.equal(5)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Page: { "type": "STRING" },
        Count: { "type": "NUMBER" },
        Added: { "type": "NUMBER" }
      })

      expect(externalDataset.simulate().toJS()).to.deep.equal([
        "Added": 4
        "Count": 4
        "Page": "some_page"
      ])

    it "a split on string with multiple limits in ascending order", ->
      ex = $('wiki').split("$page", 'Page')
        .apply('Count', '$wiki.count()')
        .sort('$Count', 'descending')
        .limit(5)
        .apply('Added', '$wiki.sum($added)')
        .limit(9)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('external')
      externalDataset = ex.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.limit.limit).to.equal(5)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Page: { "type": "STRING" },
        Count: { "type": "NUMBER" },
        Added: { "type": "NUMBER" }
      })

    it "a split on string with multiple limits in descending order", ->
      ex = $('wiki').split("$page", 'Page')
        .apply('Count', '$wiki.count()')
        .sort('$Count', 'descending')
        .limit(9)
        .apply('Added', '$wiki.sum($added)')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('external')
      externalDataset = ex.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.limit.limit).to.equal(5)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Page: { "type": "STRING" },
        Count: { "type": "NUMBER" },
        Added: { "type": "NUMBER" }
      })

    it "a split on time", ->
      ex = $('wiki').split($("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
        .apply('Count', '$wiki.count()')
        .apply('Added', '$wiki.sum($added)')
        .sort('$Count', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('chain')
      expect(ex.actions).to.have.length(2)
      externalDataset = ex.expression.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Timestamp: { "type": "TIME_RANGE" },
        Count: { "type": "NUMBER" },
        Added: { "type": "NUMBER" }
      })

      expect(externalDataset.simulate().toJS()).to.deep.equal([
        {
          "Added": 4
          "Count": 4
          "Timestamp": {
            "start": new Date('2015-03-13T07:00:00.000Z')
            "end": new Date('2015-03-14T07:00:00.000Z')
            "type": "TIME_RANGE"
          }
        }
      ])

    it "a filtered split on string", ->
      ex = $('wiki').filter('$language == "en"').split("$page", 'Page')
        .apply('Count', '$wiki.count()')
        .apply('Added', '$wiki.sum($added)')
        .sort('$Count', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('external')
      externalDataset = ex.external

      expect(
        externalDataset.filter.toJS()
      ).to.deep.equal(
        context.wiki.filter.and($("language", "STRING").is('en')).toJS()
      )

      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Page: { "type": "STRING" },
        Count: { "type": "NUMBER" },
        Added: { "type": "NUMBER" }
      })

      expect(externalDataset.simulate().toJS()).to.deep.equal([
        "Added": 4
        "Count": 4
        "Page": "some_page"
      ])

    it "a total and a split", ->
      ex = ply()
        .apply("wiki",
          $('wiki', 1)
            .apply('addedTwice', '$added * 2')
            .filter($("language").is('en'))
        )
        .apply('Count', '$wiki.count()')
        .apply('TotalAdded', '$wiki.sum($added)')
        .apply('Pages',
          $('wiki').split("$page", 'Page')
            .apply('Count', '$wiki.count()')
            .apply('Added', '$wiki.sum($added)')
            .sort('$Count', 'descending')
            .limit(5)
        )

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('chain')
      expect(ex.actions).to.have.length(1)

      externalDataset = ex.expression.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Count: { "type": "NUMBER" },
        TotalAdded: { "type": "NUMBER" }
      })

    it "a total and a split in a strange order", ->
      ex = ply()
        .apply("wiki",
          $('wiki', 1)
            .apply('addedTwice', '$added * 2')
            .filter($("language").is('en'))
        )
        .apply('Count', '$wiki.count()')
        .apply('Pages',
          $('wiki').split("$page", 'Page')
            .apply('Count', '$wiki.count()')
            .apply('Added', '$wiki.sum($added)')
            .sort('$Count', 'descending')
            .limit(5)
        )
        .apply('TotalAdded', '$wiki.sum($added)')

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('chain')
      expect(ex.actions).to.have.length(1)

      externalDataset = ex.expression.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Count: { "type": "NUMBER" },
        TotalAdded: { "type": "NUMBER" }
      })

    it "a split and another split in a strange order", ->
      ex = $('wiki').split("$page", 'Page')
        .apply('Count', '$wiki.count()')
        .sort('$Count', 'descending')
        .apply('Users'
          $('wiki').split("$user", 'User')
            .apply('Count', '$wiki.count()')
            .sort('$Count', 'descending')
            .limit(3)
        )
        .apply('Added', '$wiki.sum($added)')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('chain')
      expect(ex.actions).to.have.length(1)

      externalDataset = ex.expression.external
      expect(externalDataset.applies).to.have.length(2)
      expect(externalDataset.limit.limit).to.equal(5)
      expect(externalDataset.toJS().attributes).to.deep.equal({
        Page: { "type": "STRING" },
        Count: { "type": "NUMBER" },
        Added: { "type": "NUMBER" }
      })

    it.skip "a join of two splits", ->
      ex = $('wiki').split('$page', 'Page').join($('wikiCmp').split('$page', 'Page'))
        .apply('wiki', '$wiki.filter($page = $^Page)')
        .apply('wikiCmp', '$wikiCmp.filter($page = $^Page)')
        .apply('Count', '$wiki.count()')
        .apply('CountDiff', '$wiki.count() - $wikiCmp.count()')
        .sort('$CountDiff', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      # console.log("ex.toString()", ex.toString());

      expect(ex.op).to.equal('chain')
      expect(ex.operand.op).to.equal('join')

      externalDatasetMain = ex.operand.lhs.value
      expect(externalDatasetMain.applies).to.have.length(2)
      expect(externalDatasetMain.toJS().attributes).to.deep.equal({
        Count: { "type": "NUMBER" }
        Page: { "type": "STRING" }
        _br_0: { "type": "NUMBER" }
      })

      externalDatasetCmp = ex.operand.rhs.value
      expect(externalDatasetCmp.applies).to.have.length(1)
      expect(externalDatasetCmp.toJS().attributes).to.deep.equal({
        Page: { "type": "STRING" }
        _br_1: { "type": "NUMBER" }
      })

      expect(ex.actions[0].toString()).to.equal('.apply(CountDiff, ($_br_0 + $_br_1))')
