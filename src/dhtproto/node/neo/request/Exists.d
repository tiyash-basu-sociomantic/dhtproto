/*******************************************************************************

    Exists request protocol.

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module dhtproto.node.neo.request.Exists;

import ocean.core.VersionCheck;
import swarm.neo.node.IRequest;

/*******************************************************************************

    v0 Exists request protocol.

*******************************************************************************/

public abstract scope class ExistsProtocol_v0 : IRequest
{
    import swarm.neo.node.RequestOnConn;
    import dhtproto.common.Exists;
    import dhtproto.common.RequestCodes;
    import dhtproto.node.neo.request.core.Mixins;

    import ocean.transition;

    /// Mixin the initialiser and the connection and resources members.
    mixin IRequestHandlerRequestCore!("Exists", RequestCode.Exists);

    /// Response to client.
    private MessageType response;

    /***************************************************************************

        Called by the connection handler after the request code and version have
        been parsed from a message received over the connection, and the
        request-supported code sent in response.

        Note: the initial payload passed to this method is a slice of a buffer
        owned by the RequestOnConn. It is thus safe to assume that the contents
        of the buffer will not change over the lifetime of the request.

        Params:
            connection = request-on-conn in which the request handler is called
            resources = request resources acquirer
            init_payload = initial message payload read from the connection

    ***************************************************************************/

    public void handle ( RequestOnConn connection, Object resources,
        Const!(void)[] init_payload )
    {
        // Dummy implementation to satisfy interface definition
    }

    /***************************************************************************

        Called by the connection handler immediately after the request code and
        version have been parsed from a message received over the connection.
        Allows the request handler to process the remainder of the incoming
        message, before the connection handler sends the supported code back to
        the client.

        Note: the initial payload is a slice of the connection's read buffer.
        This means that when the request-on-conn fiber suspends, the contents of
        the buffer (hence the slice) may change. It is thus *absolutely
        essential* that this method does not suspend the fiber. (This precludes
        all I/O operations on the connection.)

        Params:
            init_payload = initial message payload read from the connection

    ***************************************************************************/

    public void preSupportedCodeSent ( Const!(void)[] init_payload )
    {
        auto parser = this.connection.event_dispatcher.message_parser();

        auto channel = parser.getArray!(char)(init_payload);
        auto key = *parser.getValue!(hash_t)(init_payload);

        // Check record key and read from channel, if ok.
        if ( this.responsibleForKey(key) )
        {
            bool found;
            if ( this.exists(channel, key, found) )
                this.response = found
                    ? MessageType.RecordExists : MessageType.NoRecord;
            else
                this.response = MessageType.Error;
        }
        else
            this.response = MessageType.WrongNode;
    }

    /***************************************************************************

        Called by the connection handler after the supported code has been sent
        back to the client.

    ***************************************************************************/

    public void postSupportedCodeSent ( )
    {
        auto ed = this.connection.event_dispatcher();

        // Send status code
        ed.send(
            ( ed.Payload payload )
            {
                payload.add(this.response);
            }
        );

        static if (!hasFeaturesFrom!("swarm", 4, 7))
            ed.flush();
    }

    /***************************************************************************

        Checks whether the node is responsible for the specified key.

        Params:
            key = key of record to write

        Returns:
            true if the node is responsible for the key

    ***************************************************************************/

    abstract protected bool responsibleForKey ( hash_t key );

    /***************************************************************************

        Checks whether a single record exists in the storage engine.

        Params:
            channel = channel to check in
            key = key of record to check
            found = out value, set to true if the record exists

        Returns:
            true if the operation succeeded; false if an error occurred

    ***************************************************************************/

    abstract protected bool exists ( cstring channel, hash_t key, out bool found );
}
