## Installation / required libraries ##

Obviously, Perl is required. Required libraries are **GLib** and **Gtk2**. To install perl and related libraries under Debian/Ubuntu:
```
sudo apt-get install perl libglib-perl libgtk2-perl
```

An alternative way to install Perl libraries (eg. for non Debian/Ubuntu Linux distros or other `*`nix-like OS) is CPAN:

```
$ sudo -H cpan -i Glib
$ sudo -H cpan -i Cairo
$ sudo -H cpan -i Gtk2
```

Windows users can install [ActivePerl](http://www.activestate.com/activeperl/downloads) and the required Perl libraries

```
C:\Temp> ppm install http://gtk2-perl.sourceforge.net/win32/ppm/Gtk2.ppd
C:\Temp> ppm install http://gtk2-perl.sourceforge.net/win32/ppm/Glib.ppd
```

Mac OSX users already have Perl, and required libraries can installed thru CPAN:

```
$ export PKG_CONFIG_PATH="/Library/Frameworks/Cairo.framework/Resources/dev/lib/pkgconfig:/Library/Frameworks/GLib.framework/Resources/dev/lib/pkgconfig:/Library/Frameworks/Gtk.framework/Resources/dev/lib/pkgconfig"

$ sudo -H cpan -i ExtUtils::Depends
$ sudo -H cpan -i ExtUtils::PkgConfig
$ sudo -H cpan -i Glib
$ sudo -H cpan -i Cairo
$ sudo -H cpan -i Gtk2
```

## Perl documentation ##
  * [Beginning Perl](http://www.perl.org/books/beginning-perl/)
  * [The Perl Reference Guide](http://www.vromans.org/johan/perlref.html)

## Editor usage ##

To launch editor:
```
perl editor.pl
```

## GTK-Perl and related documentation ##
  * [GTK2 Perl](http://gtk2-perl.sourceforge.net)
  * [GTK2 Perl Documentation](http://gtk2-perl.sourceforge.net/doc/)
  * [GTK+](http://www.gtk.org)

## Helpful documentation on SCMs ##
  * [Version control with Subversion](http://svnbook.red-bean.com/index.en.html)
  * [Controllo di versione con Subversion (Italian)](http://svnbook.red-bean.com/)
  * [Mercurial: The Definitive Guide](http://hgbook.red-bean.com/)
  * [Mercurial: la guida definitiva (Italian)](http://gpiancastelli.altervista.org/hgbook-it/)