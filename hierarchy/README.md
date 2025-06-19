# Hierarchy

Representation of a directory hierarchy. To avoid the need to perform IO while
generating the build plan, spice will scan the source directory into a data
structure which will be used in lieu of a real file system. Note that this
package doesn't provide a way of scanning the source directory. This is taken
care of by the `spice_io` package.
