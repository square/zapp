# Zapp: Continuous Integration for KIF

Now that you've had a chance to set up [KIF tests](http://github.com/square/KIF) for all of your iOS projects, you probably want a way to have a build server run them for you and report back on its results.

Zapp is that way: it's an app that continuously runs your KIF tests, polling your remote repository for changes and running your Xcode builds.

Like KIF, **Zapp also uses undocumented Apple APIs.** You won't find it on the Mac App Store, because the frameworks to control the iOS Simulator are private. Any other developer tools that have any iOS Simulator integration do the same thing.

Zapp's only dependency to test your apps is [**Xcode 4.2**](https://developer.apple.com/xcode/).

## Features

#### Runs in a login session
Unlike most other CI servers that run as headless daemons, Zapp is a fully-fledged GUI app. You can't run the iOS simulator outside of a login session, anyway.

#### Build any branch
Zapp will build any branch in your remote repository, which is useful for continuous testing of multiple build trains.

#### RSS feeds of builds
Zapp has a built-in web server that will serve up RSS feeds of your builds and their statuses. These RSS feeds are compatible with [Jenkins](http://jenkins-ci.org/) and [Hudson](http://hudson-ci.org/) and they look great in [CiMonitor](https://github.com/pivotal/cimonitor).

#### Video recording
If you look in `~/Library/Application Support/Zapp`, you'll find video recordings of the simulator from your test runs.

#### Email notifications
Zapp sends an email to your team every time a build fails and every time the build goes from red to green. You can configure this in Zapp's preferences:

## Installation

Simple: clone this repository, open `Zapp.xcodeproj` in Xcode 4.2, and click the Run button. 

## Usage

When you launch Zapp, you'll see this:

![Empty Zapp](https://github.com/square/zapp/raw/master/Documentation/Empty Zapp.png)

Click the plus button in the lower left to get started. You'll probably want to pick a local path for your repository first; if it's already cloned, Zapp will take care of the rest for you. Otherwise, you'll want to add your remote Git URL and click "Clone".

## Contributing

We're glad you're interested in Zapp, and we'd love to see where you take it.

Any contributors to the master Zapp repository must sign the [Individual Contributor License Agreement (CLA)](https://spreadsheets.google.com/spreadsheet/viewform?formkey=dDViT2xzUHAwRkI3X3k5Z0lQM091OGc6MQ&ndplr=1). It's a short form that covers our bases and makes sure you're eligible to contribute. If you already signed it for your contributions to KIF, no need to sign it again; it's the same agreement.

When you have a change you'd like to see in the master repository, [send a pull request](https://github.com/square/zapp/pulls). Before we merge your request, we'll make sure you're in the list of people who have signed a CLA.

Thanks, and happy testing!
