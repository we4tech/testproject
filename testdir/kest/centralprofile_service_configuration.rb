# $Id$
# *****************************************************************************
# Copyright (C) 2005 - 2007 somewhere in .Net ltd.
# All Rights Reserved.  No use, copying or distribution of this
# work may be made except in accordance with a valid license
# agreement from somewhere in .Net LTD.  This notice must be included on
# all copies, modifications and derivatives of this work.
# *****************************************************************************
# $LastChangedBy$
# $LastChangedDate$
# $LastChangedRevision$
# *****************************************************************************
module Centralprofile
  class Configuration

    # @@service_url = URI.parse("http://profile.somewhereinbangladesh.net/")
#    @@service_url = URI.parse("http://221.120.98.66/CProfileTest/")
    @@service_url = URI.parse("http://221.120.98.67/Cprofile/")
    def self.service_url
      return @@service_url
    end

    @@puid = "CP"
    def self.merchant_id
      return @@puid;
    end
  end
end