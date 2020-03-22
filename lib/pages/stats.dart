import 'dart:convert' as convert;
import 'package:covid_19_tracker_app/model/time_series_recovered.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:charts_flutter/flutter.dart' as charts;
import '../widgets/locations_dropdown.dart';
import '../widgets/info_circle.dart';
import '../charts/time_series_chart.dart';
import '../model/time_series_recovered.dart';

class Stats extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _StatsState();
  }
}

class _StatsState extends State<Stats> with SingleTickerProviderStateMixin {
  AnimationController _controller;
  String _country = 'World';
  Map<String, int> _locationData = Map<String, int>();
  Map<String, List<charts.Series<TimeSeriesRecovered, DateTime>>>
      _timeSeriesRecovered =
      Map<String, List<charts.Series<TimeSeriesRecovered, DateTime>>>();
  var _countFormatter = NumberFormat.compact(locale: 'en');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _startAnimation();
    _getLocationsData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _controller.stop();
    _controller.reset();
    TickerFuture tickerFuture = _controller.repeat(
      period: Duration(seconds: 1),
    );
    tickerFuture.timeout(Duration(seconds: 15), onTimeout: () {
      _controller.stop();
    });
  }

  void _setRecoveredDataByCountry(String country) {
    _startAnimation();
    setState(() {
      _country = country;
    });
  }

  void _generateTimeSeriesRecoveredData(var jsonResponse) {
    List<TimeSeriesRecovered> globalTimeSeriesData = List<TimeSeriesRecovered>();
    Map<String, int> globalTimeline = Map<String, int>();
    
    jsonResponse['locations'].forEach((location) {
      String country = location['country'];
      Map<String, dynamic> recoveredTimeline =
          location['timelines']['recovered']['timeline'];

      List<TimeSeriesRecovered> timeSeriesData = List<TimeSeriesRecovered>();
      recoveredTimeline.entries.forEach((e) {
        // location time series
        timeSeriesData.add(TimeSeriesRecovered(DateTime.parse(e.key), e.value));

        // global time line
        if(globalTimeline.containsKey(e.key)) globalTimeline[e.key] = globalTimeline[e.key] + e.value;
        else globalTimeline[e.key] = e.value;
      });

      List<charts.Series<TimeSeriesRecovered, DateTime>> chartSeries = [
        charts.Series<TimeSeriesRecovered, DateTime>(
          id: 'Recovered',
          colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
          domainFn: (TimeSeriesRecovered recovered, _) => recovered.time,
          measureFn: (TimeSeriesRecovered recovered, _) => recovered.sales,
          data: timeSeriesData,
        )
      ];

      _timeSeriesRecovered[country] = chartSeries;
    });

    // add global timeseries
    globalTimeline.entries.forEach((e) => globalTimeSeriesData.add(TimeSeriesRecovered(DateTime.parse(e.key), e.value)));

    List<charts.Series<TimeSeriesRecovered, DateTime>> chartSeries = [
        charts.Series<TimeSeriesRecovered, DateTime>(
          id: 'Recovered',
          colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
          domainFn: (TimeSeriesRecovered recovered, _) => recovered.time,
          measureFn: (TimeSeriesRecovered recovered, _) => recovered.sales,
          data: globalTimeSeriesData,
        )
      ];

      _timeSeriesRecovered['World'] = chartSeries;
  }

  void _getLocationsData() async {
    const url =
        'https://coronavirus-tracker-api.herokuapp.com/v2/locations?timelines=1';
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse = convert.jsonDecode(response.body);

      // collect location recovery data
      jsonResponse['locations'].forEach((location) =>
          _locationData[location['country']] = location['latest']['recovered']);
      _locationData['World'] = jsonResponse['latest']['recovered'];

      // generate time series chart data
      _generateTimeSeriesRecoveredData(jsonResponse);

      _setRecoveredDataByCountry('World');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(top: 50.0),
          child: LocationsDropdown(
            countries: _locationData.keys.toList()..sort(),
            callback: _setRecoveredDataByCountry,
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: 50.0),
          child: Center(
            child: InfoCircle(
              animation: _controller,
              title: 'Total Recovered',
              count: _locationData.containsKey(_country)?_countFormatter.format(_locationData[_country]):'NA',
            ),
          ),
        ),
        _timeSeriesRecovered.containsKey(_country)
            ? Container(
                height: 200.0,
                width: 200.0,
                padding: EdgeInsets.all(15),
                margin: EdgeInsets.only(top: 30),
                child: TimeSeriesChart(_timeSeriesRecovered[_country]),
              )
            : Container(
                alignment: Alignment.center,
                margin: EdgeInsets.only(top: 100),
                child: Text('No time series data available'),
              ),
      ],
    );
  }
}
