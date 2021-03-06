<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet extension-element-prefixes="url func exsl str" version="1.0" xmlns:exsl="http://exslt.org/common" xmlns:func="http://exslt.org/functions" xmlns:str="http://exslt.org/strings" xmlns:url="http://ns.nbsp.io/xsl/url" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <!--
	URL Functions v0.2

	To include these functions in your XSL, include or import the
	file and add the namespace to the stylesheet:

		<xsl:stylesheet version="1.0"
			xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			xmlns:url="http://ns.nbsp.io/xsl/url"
			extension-element-prefixes="url">

	You can then call the functions like so:

		<xsl:value-of select="url:get-query-string($current-url)" />
-->
    <!--
	Get the query string portion of a URL.
-->
    <func:function name="url:get-query-string">
        <xsl:param name="string">
        </xsl:param>
        <func:result>
            <xsl:text>
                ?
            </xsl:text>
            <xsl:choose>
                <xsl:when test="contains($string, '?')">
                    <xsl:value-of select="substring-after($string, '?')">
                    </xsl:value-of>
                </xsl:when>
                <xsl:when test="contains($string, '&')">
                    <xsl:value-of select="substring-after($string, '&')">
                    </xsl:value-of>
                </xsl:when>
            </xsl:choose>
        </func:result>
    </func:function>
    <!--
	Merge two query strings together, useful for adding a new parameter
	or changing an existing parameter without having to care what
	parameters are currently set.
-->
    <func:function name="url:merge-query-string">
        <xsl:param name="left">
        </xsl:param>
        <xsl:param name="right">
        </xsl:param>
        <xsl:variable name="left-items" select="url:parse-query-string($left)">
        </xsl:variable>
        <xsl:variable name="right-items" select="url:parse-query-string($right)">
        </xsl:variable>
        <func:result>
            <xsl:for-each select="$left-items[not(@name = $right-items/@name)]">
                <xsl:choose>
                    <xsl:when test="position() = 1">
                        <xsl:text>
                            ?
                        </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>
                            &
                        </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="@name">
                </xsl:value-of>
                <xsl:if test="@value">
                    <xsl:text>
                        =
                    </xsl:text>
                    <xsl:value-of select="@value">
                    </xsl:value-of>
                </xsl:if>
            </xsl:for-each>
            <xsl:for-each select="$right-items">
                <xsl:choose>
                    <xsl:when test="position() = 1 and not($left-items[not(@name = $right-items/@name)])">
                        <xsl:text>
                            ?
                        </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>
                            &
                        </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:value-of select="@name">
                </xsl:value-of>
                <xsl:if test="@value">
                    <xsl:text>
                        =
                    </xsl:text>
                    <xsl:value-of select="@value">
                    </xsl:value-of>
                </xsl:if>
            </xsl:for-each>
        </func:result>
    </func:function>
    <!--
	Accepts a query string and returns it as a list of items.

	Query string:
		?foo=bar&foobar

	List of items:
		<item name="foo" value="bar" />
		<item name="foobar" />
-->
    <func:function name="url:parse-query-string">
        <xsl:param name="string">
        </xsl:param>
        <xsl:variable name="raw">
            <xsl:for-each select="str:tokenize($string, '?&')">
                <xsl:choose>
                    <xsl:when test="contains(., '=')">
                        <item name="{substring-before(., '=')}" value="{substring-after(., '=')}">
                        </item>
                    </xsl:when>
                    <xsl:otherwise>
                        <item name="{.}">
                        </item>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <func:result select="exsl:node-set($raw)//item">
        </func:result>
    </func:function>
    <!--
	Accepts a URL and returns it as a list of items.

	URL:
		http://google.com/

	List of items:
		<item name="protocol" value="http"/>
		<item name="domain" value="google.com"/>
		<item name="path" value="/"/>

	URL:
		mailto:foobar@gmail.com

	List of items:
		<item name="protocol" value="mailto"/>
		<item name="user" value="foobar"/>
		<item name="domain" value="gmail.com"/>

	URL:
		http://user:password@your-api.com:81/path/name?query=string

	List of items:
		<item name="protocol" value="http"/>
		<item name="user" value="user"/>
		<item name="password" value="password"/>
		<item name="domain" value="your-api.com"/>
		<item name="port" value="81"/>
		<item name="path" value="/path/name"/>
		<item name="query" value="query=string"/>
-->
    <func:function name="url:parse-url">
        <xsl:param name="string">
        </xsl:param>
        <xsl:variable name="protocol">
            <xsl:choose>
                <!-- URL contains :// and string before :// contains only alphabetic characters -->
                <xsl:when test="
					contains($string, '://')
					and not(str:tokenize(
						substring-before($string, '://'),
						'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
					))
				">
                    <xsl:variable name="part" select="substring-before($string, '://')">
                    </xsl:variable>
                    <xsl:value-of select="substring($string, 1, string-length($part) + 3)">
                    </xsl:value-of>
                </xsl:when>
                <!-- URL contains : and string before : contains only alphabetic characters -->
                <xsl:when test="
					contains($string, ':')
					and not(str:tokenize(
						substring-before($string, ':'),
						'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
					))
				">
                    <xsl:variable name="part" select="substring-before($string, ':')">
                    </xsl:variable>
                    <xsl:value-of select="substring($string, 1, string-length($part) + 1)">
                    </xsl:value-of>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="user">
            <xsl:variable name="working" select="substring($string,
				1 + string-length($protocol)
			)">
            </xsl:variable>
            <xsl:if test="contains($working, '@')">
                <xsl:variable name="part" select="substring-before($working, '@')">
                </xsl:variable>
                <xsl:value-of select="substring($working, 1, string-length($part) + 1)">
                </xsl:value-of>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="domain">
            <xsl:variable name="working" select="substring($string,
				1 + string-length($protocol)
				+ string-length($user)
			)">
            </xsl:variable>
            <xsl:choose>
                <!-- Port number -->
                <xsl:when test="contains($working, ':')">
                    <xsl:value-of select="substring-before($working, ':')">
                    </xsl:value-of>
                </xsl:when>
                <!-- Forward slash -->
                <xsl:when test="contains($working, '/')">
                    <xsl:value-of select="substring-before($working, '/')">
                    </xsl:value-of>
                </xsl:when>
                <!-- Query string -->
                <xsl:when test="contains($working, '?')">
                    <xsl:value-of select="substring-before($working, '?')">
                    </xsl:value-of>
                </xsl:when>
                <!-- All domain -->
                <xsl:otherwise>
                    <xsl:value-of select="$working">
                    </xsl:value-of>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="port">
            <xsl:variable name="working" select="substring($string,
				1 + string-length($protocol)
				+ string-length($user)
				+ string-length($domain)
			)">
            </xsl:variable>
            <xsl:choose>
                <!-- Forward slash and contains only numeric characters -->
                <xsl:when test="
					string-length(substring-before($working, '/'))
					and not(str:tokenize(substring-before($working, '/'), ':1234567890'))
				">
                    <xsl:variable name="part" select="substring-before($working, '/')">
                    </xsl:variable>
                    <xsl:value-of select="substring($working, 1, string-length($part))">
                    </xsl:value-of>
                </xsl:when>
                <!-- Query string and contains only numeric characters -->
                <xsl:when test="
					string-length(substring-before($working, '?'))
					and not(str:tokenize(substring-before($working, '?'), ':1234567890'))
				">
                    <xsl:variable name="part" select="substring-before($working, '?')">
                    </xsl:variable>
                    <xsl:value-of select="substring($working, 1, string-length($part))">
                    </xsl:value-of>
                </xsl:when>
                <!-- All domain -->
                <xsl:when test="not(str:tokenize($working, ':1234567890'))">
                    <xsl:value-of select="$working">
                    </xsl:value-of>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="path">
            <xsl:variable name="working" select="substring($string,
				1 + string-length($protocol)
				+ string-length($user)
				+ string-length($domain)
				+ string-length($port)
			)">
            </xsl:variable>
            <xsl:value-of select="$working">
            </xsl:value-of>
        </xsl:variable>
        <xsl:variable name="raw">
            <xsl:if test="string-length($protocol)">
                <xsl:choose>
                    <xsl:when test="contains($protocol, '://')">
                        <item name="protocol" value="{substring-before($protocol, '://')}">
                        </item>
                    </xsl:when>
                    <xsl:when test="contains($protocol, ':')">
                        <item name="protocol" value="{substring-before($protocol, ':')}">
                        </item>
                    </xsl:when>
                </xsl:choose>
            </xsl:if>
            <xsl:if test="string-length($user)">
                <xsl:choose>
                    <xsl:when test="contains($user, ':')">
                        <item name="user" value="{substring-before($user, ':')}">
                        </item>
                        <item name="password" value="{substring-before(substring-after($user, ':'), '@')}">
                        </item>
                    </xsl:when>
                    <xsl:otherwise>
                        <item name="user" value="{substring-before($user, '@')}">
                        </item>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
            <xsl:if test="string-length($domain)">
                <item name="domain" value="{$domain}">
                </item>
            </xsl:if>
            <xsl:if test="string-length($port)">
                <item name="port" value="{substring-after($port, ':')}">
                </item>
            </xsl:if>
            <xsl:if test="string-length($path)">
                <xsl:choose>
                    <xsl:when test="contains($path, '?')">
                        <item name="path" value="{substring-before($path, '?')}">
                        </item>
                        <item name="query" value="{substring-after($path, '?')}">
                        </item>
                    </xsl:when>
                    <xsl:when test="contains($path, '&')">
                        <item name="path" value="{substring-before($path, '&')}">
                        </item>
                        <item name="query" value="{substring-after($path, '&')}">
                        </item>
                    </xsl:when>
                    <xsl:otherwise>
                        <item name="path" value="{$path}">
                        </item>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:variable>
        <func:result select="exsl:node-set($raw)//item">
        </func:result>
    </func:function>
</xsl:stylesheet>