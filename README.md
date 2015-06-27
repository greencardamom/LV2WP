LV2WP is a tool for mapping the LibriVox database to Wikipedia. It searches LibriVox for all its authors, then for each it searches Wikipedia to find the article name that matches that author.

### Installation 

1. Download and install Gawk 4+ if not already. "awk --version" will show installed version. 

2. Download and install tcsh if not already. http://www.tcsh.org/MostRecentRelease

3. Download, compile and install TRE agrep: https://github.com/laurikari/tre

4. Unpack LV2WP to its own directory named "lv". Set lv.awk and lv.csh executable ("chmod 755 lv.awk"), 

5. Edit init.awk and set.csh and customize path names to programs and set an Agent string

6. Edit lv.csh and lv.awk and customize path to programs in the first line. 

### Running

#### Step 1

1. Edit lv.csh and set the start and end numbers. Find the end number by testing URLs at librivox.org to see what ID number they are last up to. Each author is assigned a number and new ones are added sequentially.

2. Run lv.csh like this:

```	
./lv.csh > librivox.cv
```

It will create a database that looks like this:

```
ID# | LibriVox Name | English Wikipedia article name (best guess) | DOB-DOD | Wikipedia URL (according to LibriVox)
```

Notes:

	Field 3: This is a best guess. Usually correct.
	Field 4: Normally 4digit-4digit but might contain more such as "345 BC-456 BC"
	Field 5: May be any language such as en.wikipedia or de.wikipedia .. URL obtained from LV


#### Step 2

For those names which Step 1 could not determine, this step will do more in-depth searching of Wikipedia using the program lv.awk (an adaption of pg.awk)

1. Feed the database created in "Step 1" to the program lv.awk 

````
./lv -j librivox.cv -k librivoxnew.cv -z librivoxnew.log > librivoxnew.run
````

2. Check the logfile (librivoxnew.log) for any "Possibles" and manually edit librivoxnew.cv to update after the name has been manually verified as being correct.

3. Rename librivoxnew.cv to librivox.cv


#### Important: Re-running 

If you have already run lv.csh and are running it again, you will want to skip the names already found. Copy the prior version of librivox.cv to librivox-cache.cv and lv.csh will skip searching on any records where field #3 is not equal to "Unknown".


### Credits

By User:Green Cardamom 

Copyright MIT License 2015
